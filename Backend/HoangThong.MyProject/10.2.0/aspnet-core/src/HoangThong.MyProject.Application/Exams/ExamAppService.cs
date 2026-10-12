using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Abp.Application.Services;
using Abp.Domain.Repositories;
using Abp.UI;
using HoangThong.MyProject.Exams.Dto;
using Microsoft.EntityFrameworkCore;

namespace HoangThong.MyProject.Exams
{
    public interface IExamAppService : IApplicationService
    {
        Task<List<ExamListDto>> GetAllAsync();
        Task<List<ExamListDto>> GetAvailableAsync();
        Task<ExamPreviewDto> GetPreviewAsync(int id);
        Task<ExamPreviewDto> GetAvailablePreviewAsync(int id);
        Task UpdateExamAsync(UpdateExamInput input);
        Task UpdateQuestionAsync(UpdateQuestionInput input);
        Task DeleteAsync(int id);
    }

    public class ExamAppService : MyProjectAppServiceBase, IExamAppService
    {
        private readonly IRepository<Exam, int> _exams;
        private readonly IRepository<ToeicQuestion, int> _questions;

        public ExamAppService(
            IRepository<Exam, int> exams,
            IRepository<ToeicQuestion, int> questions)
        {
            _exams = exams;
            _questions = questions;
        }

        public async Task<List<ExamListDto>> GetAllAsync()
        {
            var now = System.DateTime.UtcNow;
            var unscheduledTime = Exam.UnscheduledTime;
            return await _exams.GetAll().OrderByDescending(exam => exam.Id)
                .Select(exam => new ExamListDto
                {
                    Id = exam.Id,
                    Name = exam.Name,
                    DurationMinutes = Exam.DefaultDurationMinutes,
                    TotalQuestions = exam.TotalQuestions,
                    IsPublished = exam.EndAt > now && exam.EndAt > exam.StartAt,
                    StartAt = exam.StartAt == unscheduledTime ? null : exam.StartAt,
                    EndAt = exam.EndAt == unscheduledTime ? null : exam.EndAt,
                    CreatedAt = exam.CreatedAt
                })
                .ToListAsync();
        }

        public async Task<List<ExamListDto>> GetAvailableAsync()
        {
            var now = System.DateTime.UtcNow;
            return await _exams.GetAll()
                .Where(exam => exam.StartAt <= now && exam.EndAt > now)
                .OrderByDescending(exam => exam.StartAt)
                .Select(exam => new ExamListDto
                {
                    Id = exam.Id,
                    Name = exam.Name,
                    DurationMinutes = Exam.DefaultDurationMinutes,
                    TotalQuestions = exam.TotalQuestions,
                    IsPublished = true,
                    StartAt = exam.StartAt,
                    EndAt = exam.EndAt,
                    CreatedAt = exam.CreatedAt
                })
                .ToListAsync();
        }

        public async Task<ExamPreviewDto> GetAvailablePreviewAsync(int id)
        {
            var now = System.DateTime.UtcNow;
            var isAvailable = await _exams.GetAll().AnyAsync(exam =>
                exam.Id == id && exam.StartAt <= now && exam.EndAt > now);
            if (!isAvailable)
                throw new UserFriendlyException("This examination is not available.");
            return await GetPreviewAsync(id);
        }

        public async Task UpdateExamAsync(UpdateExamInput input)
        {
            if (string.IsNullOrWhiteSpace(input.Name))
                throw new UserFriendlyException("Exam name is required.");
            if (input.Name.Trim().Length > 255)
                throw new UserFriendlyException("Exam name cannot exceed 255 characters.");
            if (input.DurationMinutes <= 0)
                throw new UserFriendlyException("Duration must be greater than zero.");

            var startAt = input.StartAt?.ToUniversalTime();
            var endAt = input.EndAt?.ToUniversalTime();
            if (input.IsPublished &&
                (!startAt.HasValue || !endAt.HasValue ||
                 endAt <= startAt || endAt <= System.DateTime.UtcNow))
                throw new UserFriendlyException(
                    "Set a valid schedule with an end time in the future before enabling an exam.");

            var exam = await _exams.GetAsync(input.Id);
            exam.Name = input.Name.Trim();
            exam.DurationMinutes = Exam.DefaultDurationMinutes;
            exam.StartAt = input.IsPublished ? startAt.Value : Exam.UnscheduledTime;
            exam.EndAt = input.IsPublished ? endAt.Value : Exam.UnscheduledTime;
        }

        public async Task DeleteAsync(int id)
        {
            await _exams.GetAsync(id);
            await _exams.DeleteAsync(id);
        }

        public async Task<ExamPreviewDto> GetPreviewAsync(int id)
        {
            var exam = await _exams.GetAll().FirstOrDefaultAsync(item => item.Id == id);
            if (exam == null) throw new UserFriendlyException("Exam not found.");

            var questions = await _questions.GetAll()
                .Where(question => question.ExamId == id)
                .OrderBy(question => question.Id)
                .ToListAsync();
            var questionNumbers = questions
                .Select((question, index) => new { question.Id, Number = index + 101 })
                .ToDictionary(question => question.Id, question => question.Number);

            var groups = new List<GroupDto>();
            for (var index = 0; index < questions.Count; index++)
            {
                var question = questions[index];
                var number = index + 101;
                var part = GetPart(number);
                var group = part != 5 && groups.Count > 0 &&
                    groups[groups.Count - 1].Part == part &&
                    string.Equals(
                        groups[groups.Count - 1].Content,
                        question.PassageText,
                        System.StringComparison.Ordinal)
                    ? groups[groups.Count - 1]
                    : null;
                if (group == null)
                {
                    group = new GroupDto
                    {
                        Part = part,
                        Content = part == 5 ? null : question.PassageText
                    };
                    groups.Add(group);
                }
                group.Questions.Add(new QuestionDto
                {
                    Id = question.Id,
                    Number = questionNumbers[question.Id],
                    Text = question.QuestionText,
                    Options = new List<OptionDto>
                    {
                        new OptionDto { Label = "A", Text = question.Option1, IsCorrect = question.CorrectAnswer == 1 },
                        new OptionDto { Label = "B", Text = question.Option2, IsCorrect = question.CorrectAnswer == 2 },
                        new OptionDto { Label = "C", Text = question.Option3, IsCorrect = question.CorrectAnswer == 3 },
                        new OptionDto { Label = "D", Text = question.Option4, IsCorrect = question.CorrectAnswer == 4 }
                    }
                });
            }

            return new ExamPreviewDto
            {
                Id = exam.Id,
                Name = exam.Name,
                Groups = groups
            };
        }

        public async Task UpdateQuestionAsync(UpdateQuestionInput input)
        {
            if (string.IsNullOrWhiteSpace(input.Text))
                throw new UserFriendlyException("Question text is required.");
            if (input.Options == null)
                throw new UserFriendlyException("Question options are required.");
            var correctAnswer = "ABCD".IndexOf(
                input.CorrectLabel?.ToUpperInvariant() ?? string.Empty);
            if (correctAnswer < 0)
                throw new UserFriendlyException("Correct answer must be A, B, C, or D.");

            var question = await _questions.GetAll()
                .FirstOrDefaultAsync(item => item.Id == input.QuestionId);
            if (question == null) throw new UserFriendlyException("Question not found.");
            question.QuestionText = input.Text;
            var examQuestions = await _questions.GetAll()
                .Where(item => item.ExamId == question.ExamId)
                .OrderBy(item => item.Id)
                .ToListAsync();
            var questionIndex = examQuestions.FindIndex(item => item.Id == question.Id);
            var questionPart = GetPart(questionIndex + 101);
            if (questionPart >= 6)
            {
                var originalPassage = question.PassageText;
                for (var index = questionIndex; index >= 0; index--)
                {
                    if (GetPart(index + 101) != questionPart ||
                        !string.Equals(
                            examQuestions[index].PassageText,
                            originalPassage,
                            System.StringComparison.Ordinal))
                        break;
                    examQuestions[index].PassageText = input.PassageText ?? string.Empty;
                }
                for (var index = questionIndex + 1; index < examQuestions.Count; index++)
                {
                    if (GetPart(index + 101) != questionPart ||
                        !string.Equals(
                            examQuestions[index].PassageText,
                            originalPassage,
                            System.StringComparison.Ordinal))
                        break;
                    examQuestions[index].PassageText = input.PassageText ?? string.Empty;
                }
            }
            question.Option1 = input.Options.FirstOrDefault(option =>
                string.Equals(option.Label, "A", System.StringComparison.OrdinalIgnoreCase))?.Text ?? string.Empty;
            question.Option2 = input.Options.FirstOrDefault(option =>
                string.Equals(option.Label, "B", System.StringComparison.OrdinalIgnoreCase))?.Text ?? string.Empty;
            question.Option3 = input.Options.FirstOrDefault(option =>
                string.Equals(option.Label, "C", System.StringComparison.OrdinalIgnoreCase))?.Text ?? string.Empty;
            question.Option4 = input.Options.FirstOrDefault(option =>
                string.Equals(option.Label, "D", System.StringComparison.OrdinalIgnoreCase))?.Text ?? string.Empty;
            question.CorrectAnswer = correctAnswer + 1;
        }

        private static int GetPart(int questionNumber) =>
            questionNumber <= 130 ? 5 : questionNumber <= 146 ? 6 : 7;
    }
}
