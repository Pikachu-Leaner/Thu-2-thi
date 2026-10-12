using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System;
using Abp.Domain.Entities;

namespace HoangThong.MyProject.Exams
{
    public class Exam : Entity<int>
    {
        public const int DefaultDurationMinutes = 75;

        public static readonly DateTime UnscheduledTime =
            new DateTime(1753, 1, 1, 0, 0, 0, DateTimeKind.Utc);

        [Required, StringLength(255)]
        public string Name { get; set; }
        public DateTime StartAt { get; set; }
        public DateTime EndAt { get; set; }
        public int DurationMinutes { get; set; } = DefaultDurationMinutes;
        public int TotalQuestions { get; set; } = 100;
        public DateTime? CreatedAt { get; set; }
        public virtual ICollection<ToeicQuestion> Questions { get; set; } = new List<ToeicQuestion>();
    }
}
