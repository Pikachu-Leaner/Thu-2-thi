using Abp.Authorization;
using Abp.Runtime.Session;
using HoangThong.MyProject.Configuration.Dto;
using System.Threading.Tasks;

namespace HoangThong.MyProject.Configuration;

[AbpAuthorize]
public class ConfigurationAppService : MyProjectAppServiceBase, IConfigurationAppService
{
    public async Task ChangeUiTheme(ChangeUiThemeInput input)
    {
        await SettingManager.ChangeSettingForUserAsync(AbpSession.ToUserIdentifier(), AppSettingNames.UiTheme, input.Theme);
    }
}
