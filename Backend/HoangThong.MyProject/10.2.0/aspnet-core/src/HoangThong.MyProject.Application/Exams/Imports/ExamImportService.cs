using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Abp.Application.Services;
using Abp.Domain.Uow;

namespace HoangThong.MyProject.Exams.Import
{
    public class ImportExamResult { public int ExamId { get; set; } public List<string> Errors { get; set; } = new List<string>(); }

    public interface IExamImportService : IApplicationService
    {
        Task<ImportExamResult> ImportAsync(string name, Stream docx);
    }

    public class ExamImportService : MyProjectAppServiceBase, IExamImportService
    {
        private readonly IExamImportStore _examImportStore;
        public ExamImportService(IExamImportStore examImportStore) { _examImportStore = examImportStore; }

        [UnitOfWork]
        public async Task<ImportExamResult> ImportAsync(
            string name,
            Stream docx)
        {
            var result = new ImportExamResult();
            using var documentCopy = new MemoryStream();
            await docx.CopyToAsync(documentCopy);
            var documentBytes = documentCopy.ToArray();
            using var parserStream = new MemoryStream(documentBytes);
            var parsed = new ExamDocxParser().Parse(parserStream, result.Errors);
            if (string.IsNullOrWhiteSpace(name))
                result.Errors.Add("Exam name is required.");
            else if (name.Trim().Length > 255)
                result.Errors.Add("Exam name cannot exceed 255 characters.");
            if (result.Errors.Count > 0) return result;          // nothing is saved

            var exam = new Exam
            {
                Name = name.Trim(),
                DurationMinutes = Exam.DefaultDurationMinutes,
                TotalQuestions = parsed.Groups.Sum(group => group.Questions.Count),
                StartAt = Exam.UnscheduledTime,
                EndAt = Exam.UnscheduledTime
            };
            foreach (var g in parsed.Groups)
            {
                foreach (var pq in g.Questions)
                {
                    var question = new ToeicQuestion
                    {
                        PassageText = g.Passage,
                        QuestionText = pq.Text,
                        Option1 = pq.Answers[0],
                        Option2 = pq.Answers[1],
                        Option3 = pq.Answers[2],
                        Option4 = pq.Answers[3],
                        CorrectAnswer = pq.Correct,
                        Exam = exam
                    };
                    exam.Questions.Add(question);
                }
            }
            await _examImportStore.InsertAsync(exam);
            result.ExamId = exam.Id;
            return result;
        }
    }
}