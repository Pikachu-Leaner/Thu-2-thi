using Abp.AspNetCore;
using Abp.AspNetCore.Configuration;
using Abp.AspNetCore.SignalR;
using Abp.Modules;
using Abp.Reflection.Extensions;
using Abp.Zero.Configuration;
using HoangThong.MyProject.Authentication.JwtBearer;
using HoangThong.MyProject.Configuration;
using HoangThong.MyProject.EntityFrameworkCore;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.ApplicationParts;
using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.Tokens;
using System;
using System.Text;

namespace HoangThong.MyProject
{
    [DependsOn(
         typeof(MyProjectApplicationModule),
         typeof(MyProjectEntityFrameworkModule),
         typeof(AbpAspNetCoreModule)
        , typeof(AbpAspNetCoreSignalRModule)
     )]
    public class MyProjectWebCoreModule : AbpModule
    {
        private readonly IWebHostEnvironment _env;
        private readonly IConfigurationRoot _appConfiguration;
        private readonly bool _useExamOnlyDatabase;

        public MyProjectWebCoreModule(
            IWebHostEnvironment env,
            MyProjectEntityFrameworkModule entityFrameworkModule)
        {
            _env = env;
            _appConfiguration = env.GetAppConfiguration();
            _useExamOnlyDatabase =
                _appConfiguration.GetValue<bool>("App:UseExamOnlyDatabase");
            entityFrameworkModule.SkipDbSeed = _useExamOnlyDatabase;
        }

        public override void PreInitialize()
        {
            Configuration.DefaultNameOrConnectionString = _appConfiguration.GetConnectionString(
                MyProjectConsts.ConnectionStringName
            );

            if (!_useExamOnlyDatabase)
            {
                Configuration.Modules.Zero().LanguageManagement.EnableDbLocalization();
            }

            Configuration.BackgroundJobs.IsJobExecutionEnabled = !_useExamOnlyDatabase;
            Configuration.Auditing.IsEnabled = !_useExamOnlyDatabase;

            Configuration.Modules.AbpAspNetCore()
                 .CreateControllersForAppServices(
                     typeof(MyProjectApplicationModule).GetAssembly()
                 );

            ConfigureTokenAuth();
        }

        private void ConfigureTokenAuth()
        {
            IocManager.Register<TokenAuthConfiguration>();
            var tokenAuthConfig = IocManager.Resolve<TokenAuthConfiguration>();

            tokenAuthConfig.SecurityKey = new SymmetricSecurityKey(Encoding.ASCII.GetBytes(_appConfiguration["Authentication:JwtBearer:SecurityKey"]));
            tokenAuthConfig.Issuer = _appConfiguration["Authentication:JwtBearer:Issuer"];
            tokenAuthConfig.Audience = _appConfiguration["Authentication:JwtBearer:Audience"];
            tokenAuthConfig.SigningCredentials = new SigningCredentials(tokenAuthConfig.SecurityKey, SecurityAlgorithms.HmacSha256);
            tokenAuthConfig.Expiration = TimeSpan.FromDays(1);
        }

        public override void Initialize()
        {
            IocManager.RegisterAssemblyByConvention(typeof(MyProjectWebCoreModule).GetAssembly());
        }

        public override void PostInitialize()
        {
            IocManager.Resolve<ApplicationPartManager>()
                .AddApplicationPartsIfNotAddedBefore(typeof(MyProjectWebCoreModule).Assembly);
        }
    }
}
