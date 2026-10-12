using System.ComponentModel.DataAnnotations;
using Abp.Domain.Entities;

namespace HoangThong.MyProject.Exams
{
    public class ToeicQuestion : Entity<int>
    {
        public int ExamId { get; set; }
        public virtual Exam Exam { get; set; }
        public string PassageText { get; set; }
        [Required]
        public string QuestionText { get; set; } = string.Empty;
        [Required]
        public string Option1 { get; set; } = string.Empty;
        [Required]
        public string Option2 { get; set; } = string.Empty;
        [Required]
        public string Option3 { get; set; } = string.Empty;
        [Required]
        public string Option4 { get; set; } = string.Empty;
        public int CorrectAnswer { get; set; }
    }
}
