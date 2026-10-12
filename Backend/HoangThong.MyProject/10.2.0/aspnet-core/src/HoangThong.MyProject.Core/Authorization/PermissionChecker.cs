using Abp.Authorization;
using HoangThong.MyProject.Authorization.Roles;
using HoangThong.MyProject.Authorization.Users;

namespace HoangThong.MyProject.Authorization;

public class PermissionChecker : PermissionChecker<Role, User>
{
    public PermissionChecker(UserManager userManager)
        : base(userManager)
    {
    }
}
