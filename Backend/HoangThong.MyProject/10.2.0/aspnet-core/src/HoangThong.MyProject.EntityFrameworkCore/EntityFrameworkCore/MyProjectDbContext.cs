using Abp.Zero.EntityFrameworkCore;
using HoangThong.MyProject.Authorization.Roles;
using HoangThong.MyProject.Authorization.Users;
using HoangThong.MyProject.Exams;
using HoangThong.MyProject.MultiTenancy;
using Microsoft.EntityFrameworkCore;

namespace HoangThong.MyProject.EntityFrameworkCore;

public class MyProjectDbContext : AbpZeroDbContext<Tenant, Role, User, MyProjectDbContext>
{
    /* Define a DbSet for each entity of the application */
    public DbSet<Exam> Exams { get; set; }
    public DbSet<ToeicQuestion> ToeicQuestions { get; set; }

    public MyProjectDbContext(DbContextOptions<MyProjectDbContext> options)
        : base(options)
    {
    }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<Exam>(entity =>
        {
            entity.ToTable("Exams");
            entity.Property(exam => exam.Id).HasColumnName("ExamID").ValueGeneratedNever();
            entity.Property(exam => exam.Name).HasColumnName("ExamName").HasMaxLength(255).IsRequired();
            entity.Property(exam => exam.StartAt).HasColumnName("StartTime").HasColumnType("datetime");
            entity.Property(exam => exam.EndAt).HasColumnName("EndTime").HasColumnType("datetime");
            entity.Property(exam => exam.DurationMinutes).HasColumnName("TimeLimitMinutes");
            entity.Property(exam => exam.TotalQuestions).HasDefaultValue(0);
            entity.Property(exam => exam.CreatedAt)
                .HasColumnName("CreatedAt")
                .HasColumnType("datetime")
                .HasDefaultValueSql("GETDATE()");
        });

        modelBuilder.Entity<ToeicQuestion>(entity =>
        {
            entity.ToTable("ToeicQuestions");
            entity.Property(question => question.Id).HasColumnName("QuestionID").ValueGeneratedNever();
            entity.Property(question => question.ExamId).HasColumnName("ExamID");
            entity.Property(question => question.PassageText).HasColumnName("PassageText").IsRequired(false);
            entity.Property(question => question.QuestionText).HasColumnName("QuestionText").IsRequired();
            entity.Property(question => question.Option1).HasColumnName("Option1").IsRequired();
            entity.Property(question => question.Option2).HasColumnName("Option2").IsRequired();
            entity.Property(question => question.Option3).HasColumnName("Option3").IsRequired();
            entity.Property(question => question.Option4).HasColumnName("Option4").IsRequired();
            entity.Property(question => question.CorrectAnswer).HasColumnName("CorrectAnswer");
            entity.HasOne(question => question.Exam)
                .WithMany(exam => exam.Questions)
                .HasForeignKey(question => question.ExamId)
                .OnDelete(DeleteBehavior.Cascade);
        });
    }
}
