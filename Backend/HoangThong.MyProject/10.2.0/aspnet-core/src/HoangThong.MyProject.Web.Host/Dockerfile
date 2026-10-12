FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build

WORKDIR /src
COPY ["src/HoangThong.MyProject.Web.Host/HoangThong.MyProject.Web.Host.csproj", "src/HoangThong.MyProject.Web.Host/"]
COPY ["src/HoangThong.MyProject.Web.Core/HoangThong.MyProject.Web.Core.csproj", "src/HoangThong.MyProject.Web.Core/"]
COPY ["src/HoangThong.MyProject.Application/HoangThong.MyProject.Application.csproj", "src/HoangThong.MyProject.Application/"]
COPY ["src/HoangThong.MyProject.Core/HoangThong.MyProject.Core.csproj", "src/HoangThong.MyProject.Core/"]
COPY ["src/HoangThong.MyProject.EntityFrameworkCore/HoangThong.MyProject.EntityFrameworkCore.csproj", "src/HoangThong.MyProject.EntityFrameworkCore/"]
WORKDIR "/src/src/HoangThong.MyProject.Web.Host"
RUN dotnet restore 

WORKDIR /src
COPY ["src/HoangThong.MyProject.Web.Host", "src/HoangThong.MyProject.Web.Host"]
COPY ["src/HoangThong.MyProject.Web.Core", "src/HoangThong.MyProject.Web.Core"]
COPY ["src/HoangThong.MyProject.Application", "src/HoangThong.MyProject.Application"]
COPY ["src/HoangThong.MyProject.Core", "src/HoangThong.MyProject.Core"]
COPY ["src/HoangThong.MyProject.EntityFrameworkCore", "src/HoangThong.MyProject.EntityFrameworkCore"]
WORKDIR "/src/src/HoangThong.MyProject.Web.Host"
RUN dotnet publish -c Release -o /publish --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:8.0
EXPOSE 80
WORKDIR /app
COPY --from=build /publish .
ENTRYPOINT ["dotnet", "HoangThong.MyProject.Web.Host.dll"]
