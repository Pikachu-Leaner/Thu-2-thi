using System;
using HoangThong.MyProject.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace HoangThong.MyProject.Migrations
{
    [DbContext(typeof(MyProjectDbContext))]
    [Migration("20261012110000_ExamLifecycle")]
    public partial class ExamLifecycle : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "StartAt",
                table: "Exams",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "EndAt",
                table: "Exams",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "DeleteAt",
                table: "Exams",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "OriginalFileName",
                table: "Exams",
                type: "nvarchar(260)",
                maxLength: 260,
                nullable: true);

            migrationBuilder.AddColumn<byte[]>(
                name: "OriginalDocument",
                table: "Exams",
                type: "varbinary(max)",
                nullable: true);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(name: "StartAt", table: "Exams");
            migrationBuilder.DropColumn(name: "EndAt", table: "Exams");
            migrationBuilder.DropColumn(name: "DeleteAt", table: "Exams");
            migrationBuilder.DropColumn(name: "OriginalFileName", table: "Exams");
            migrationBuilder.DropColumn(name: "OriginalDocument", table: "Exams");
        }
    }
}
