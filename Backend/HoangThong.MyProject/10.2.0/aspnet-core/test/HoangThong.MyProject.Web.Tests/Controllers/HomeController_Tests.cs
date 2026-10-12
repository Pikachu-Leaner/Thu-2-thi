using HoangThong.MyProject.Web.Host.Controllers;
using Shouldly;
using System.Net;
using System.Threading.Tasks;
using Xunit;

namespace HoangThong.MyProject.Web.Tests.Controllers;

public class HomeController_Tests : MyProjectWebTestBase
{
    [Fact]
    public async Task Index_Test()
    {
        var response = await Client.GetAsync(
            GetUrl<HomeController>(nameof(HomeController.Index))
        );

        response.StatusCode.ShouldBe(HttpStatusCode.Found);
        response.Headers.Location?.ToString().ShouldBe("/swagger");
    }
}