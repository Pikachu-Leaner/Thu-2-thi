using Abp.Application.Services;
using HoangThong.MyProject.Sessions.Dto;
using System.Threading.Tasks;

namespace HoangThong.MyProject.Sessions;

public interface ISessionAppService : IApplicationService
{
    Task<GetCurrentLoginInformationsOutput> GetCurrentLoginInformations();
}
