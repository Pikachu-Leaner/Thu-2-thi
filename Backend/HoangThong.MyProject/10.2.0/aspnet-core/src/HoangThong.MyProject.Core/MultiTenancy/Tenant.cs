using Abp.MultiTenancy;
using HoangThong.MyProject.Authorization.Users;

namespace HoangThong.MyProject.MultiTenancy;

public class Tenant : AbpTenant<User>
{
    public Tenant()
    {
    }

    public Tenant(string tenancyName, string name)
        : base(tenancyName, name)
    {
    }
}
