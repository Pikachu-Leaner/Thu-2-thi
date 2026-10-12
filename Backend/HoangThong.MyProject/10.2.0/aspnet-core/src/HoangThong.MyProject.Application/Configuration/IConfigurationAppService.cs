using HoangThong.MyProject.Configuration.Dto;
using System.Threading.Tasks;

namespace HoangThong.MyProject.Configuration;

public interface IConfigurationAppService
{
    Task ChangeUiTheme(ChangeUiThemeInput input);
}
