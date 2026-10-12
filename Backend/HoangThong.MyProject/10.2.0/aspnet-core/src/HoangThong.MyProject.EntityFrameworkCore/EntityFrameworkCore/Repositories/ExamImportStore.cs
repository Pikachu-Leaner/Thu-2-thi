using System.Threading.Tasks;
using Abp.Dependency;
using Abp.EntityFrameworkCore;
using HoangThong.MyProject.Exams;
using Microsoft.EntityFrameworkCore;

namespace HoangThong.MyProject.EntityFrameworkCore.Repositories
{
    public sealed class ExamImportStore : IExamImportStore, ITransientDependency
    {
        private readonly IDbContextProvider<MyProjectDbContext> _dbContextProvider;

        public ExamImportStore(IDbContextProvider<MyProjectDbContext> dbContextProvider)
        {
            _dbContextProvider = dbContextProvider;
        }

        public async Task InsertAsync(Exam exam)
        {
            var dbContext = _dbContextProvider.GetDbContext();

            exam.Id = await dbContext.Database
                .SqlQueryRaw<int>(
                    "SELECT ISNULL(MAX([ExamID]), 0) + 1 AS [Value] " +
                    "FROM [dbo].[Exams] WITH (UPDLOCK, HOLDLOCK)")
                .SingleAsync();

            var nextQuestionId = await dbContext.Database
                .SqlQueryRaw<int>(
                    "SELECT ISNULL(MAX([QuestionID]), 0) + 1 AS [Value] " +
                    "FROM [dbo].[ToeicQuestions] WITH (UPDLOCK, HOLDLOCK)")
                .SingleAsync();

            foreach (var question in exam.Questions)
            {
                question.Id = nextQuestionId++;
                question.ExamId = exam.Id;
                question.Exam = exam;
            }

            dbContext.Exams.Add(exam);
            await dbContext.SaveChangesAsync();
        }
    }
}
