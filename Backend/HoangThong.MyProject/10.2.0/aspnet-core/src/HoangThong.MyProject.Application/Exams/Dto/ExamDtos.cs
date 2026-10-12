using System.Collections.Generic;

namespace HoangThong.MyProject.Exams.Dto
{
    using System;

    public class ExamListDto
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public int DurationMinutes { get; set; }
        public int TotalQuestions { get; set; }
        public bool IsPublished { get; set; }
        public DateTime? StartAt { get; set; }
        public DateTime? EndAt { get; set; }
        public DateTime? CreatedAt { get; set; }
    }

    public class UpdateExamInput
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public int DurationMinutes { get; set; }
        public bool IsPublished { get; set; }
        public DateTime? StartAt { get; set; }
        public DateTime? EndAt { get; set; }
    }

    public class OptionDto { public string Label { get; set; } public string Text { get; set; } public bool IsCorrect { get; set; } }
    public class QuestionDto { public int Id { get; set; } public int Number { get; set; } public string Text { get; set; } public List<OptionDto> Options { get; set; } = new List<OptionDto>(); }
    public class GroupDto { public int Part { get; set; } public string Content { get; set; } public List<QuestionDto> Questions { get; set; } = new List<QuestionDto>(); }
    public class ExamPreviewDto { public int Id { get; set; } public string Name { get; set; } public List<GroupDto> Groups { get; set; } = new List<GroupDto>(); }
    public class UpdateQuestionInput { public int QuestionId { get; set; } public string Text { get; set; } public string PassageText { get; set; } public string CorrectLabel { get; set; } public List<OptionDto> Options { get; set; } = new List<OptionDto>(); }
}