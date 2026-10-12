using System.Threading.Tasks;

namespace HoangThong.MyProject.Exams
{
    public interface IExamImportStore
    {
        Task InsertAsync(Exam exam);
    }
}
