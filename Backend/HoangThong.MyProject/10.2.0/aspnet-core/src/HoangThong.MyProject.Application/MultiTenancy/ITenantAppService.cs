using Abp.Application.Services;
using HoangThong.MyProject.MultiTenancy.Dto;

namespace HoangThong.MyProject.MultiTenancy;

public interface ITenantAppService : IAsyncCrudAppService<TenantDto, int, PagedTenantResultRequestDto, CreateTenantDto, TenantDto>
{
}

