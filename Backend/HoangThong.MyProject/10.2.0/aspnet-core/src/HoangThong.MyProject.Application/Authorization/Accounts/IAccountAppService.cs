using Abp.Application.Services;
using HoangThong.MyProject.Authorization.Accounts.Dto;
using System.Threading.Tasks;

namespace HoangThong.MyProject.Authorization.Accounts;

public interface IAccountAppService : IApplicationService
{
    Task<IsTenantAvailableOutput> IsTenantAvailable(IsTenantAvailableInput input);

    Task<RegisterOutput> Register(RegisterInput input);
}
