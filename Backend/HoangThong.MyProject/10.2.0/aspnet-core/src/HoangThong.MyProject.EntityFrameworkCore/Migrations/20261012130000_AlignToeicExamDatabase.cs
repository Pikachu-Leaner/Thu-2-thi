using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace HoangThong.MyProject.Migrations
{
    public partial class AlignToeicExamDatabase : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Exams_New",
                columns: table => new
                {
                    ExamID = table.Column<int>(type: "int", nullable: false),
                    ExamName = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: false),
                    StartTime = table.Column<DateTime>(type: "datetime", nullable: false),
                    EndTime = table.Column<DateTime>(type: "datetime", nullable: false),
                    TimeLimitMinutes = table.Column<int>(type: "int", nullable: false),
                    TotalQuestions = table.Column<int>(type: "int", nullable: false, defaultValue: 0),
                    CreatedAt = table.Column<DateTime>(type: "datetime", nullable: true, defaultValueSql: "GETDATE()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Exams_New", x => x.ExamID);
                });

            migrationBuilder.CreateTable(
                name: "ToeicQuestions",
                columns: table => new
                {
                    QuestionID = table.Column<int>(type: "int", nullable: false),
                    ExamID = table.Column<int>(type: "int", nullable: false),
                    PassageText = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    QuestionText = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    Option1 = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    Option2 = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    Option3 = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    Option4 = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    CorrectAnswer = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ToeicQuestions", x => x.QuestionID);
                });

            migrationBuilder.Sql(
                """
                IF EXISTS (SELECT 1 FROM dbo.Exams WHERE Id < -2147483648 OR Id > 2147483647)
                    THROW 51001, 'An existing exam ID cannot be represented as an INT.', 1;
                IF EXISTS (SELECT 1 FROM dbo.Questions WHERE Id < -2147483648 OR Id > 2147483647)
                    THROW 51002, 'An existing question ID cannot be represented as an INT.', 1;
                IF EXISTS (SELECT 1 FROM dbo.Exams WHERE DATALENGTH(Name) > 510)
                    THROW 51003, 'An existing exam name exceeds the target 255-character limit.', 1;

                DECLARE @UnscheduledTime DATETIME = CONVERT(DATETIME, '17530101', 112);

                INSERT INTO dbo.Exams_New
                    (ExamID, ExamName, StartTime, EndTime, TimeLimitMinutes, TotalQuestions, CreatedAt)
                SELECT
                    CONVERT(INT, Id),
                    Name,
                    CASE WHEN IsDeleted = 0 AND IsPublished = 1
                                   AND StartAt IS NOT NULL AND EndAt > StartAt
                         THEN CONVERT(DATETIME, StartAt) ELSE @UnscheduledTime END,
                    CASE WHEN IsDeleted = 0 AND IsPublished = 1
                                   AND StartAt IS NOT NULL AND EndAt > StartAt
                         THEN CONVERT(DATETIME, EndAt) ELSE @UnscheduledTime END,
                    DurationMinutes,
                    TotalQuestions,
                    CONVERT(DATETIME, CreationTime)
                FROM dbo.Exams
                WHERE IsDeleted = 0;

                INSERT INTO dbo.ToeicQuestions
                    (QuestionID, ExamID, PassageText, QuestionText, Option1, Option2, Option3, Option4, CorrectAnswer)
                SELECT
                    CONVERT(INT, q.Id),
                    CONVERT(INT, qg.ExamId),
                    qg.Content,
                    COALESCE(q.Text, N''),
                    COALESCE(MAX(CASE WHEN UPPER(qo.Label) = N'A' THEN qo.Text END), N''),
                    COALESCE(MAX(CASE WHEN UPPER(qo.Label) = N'B' THEN qo.Text END), N''),
                    COALESCE(MAX(CASE WHEN UPPER(qo.Label) = N'C' THEN qo.Text END), N''),
                    COALESCE(MAX(CASE WHEN UPPER(qo.Label) = N'D' THEN qo.Text END), N''),
                    COALESCE(MAX(CASE WHEN qo.IsCorrect = 1 THEN
                        CASE UPPER(qo.Label) WHEN N'A' THEN 1 WHEN N'B' THEN 2
                            WHEN N'C' THEN 3 WHEN N'D' THEN 4 END END), 0)
                FROM dbo.Questions AS q
                INNER JOIN dbo.QuestionGroups AS qg ON qg.Id = q.QuestionGroupId
                INNER JOIN dbo.Exams AS e ON e.Id = qg.ExamId AND e.IsDeleted = 0
                LEFT JOIN dbo.QuestionOptions AS qo ON qo.QuestionId = q.Id
                GROUP BY q.Id, qg.ExamId, qg.Content, q.Text;
                """);

            migrationBuilder.DropTable(name: "QuestionOptions");
            migrationBuilder.DropTable(name: "Questions");
            migrationBuilder.DropTable(name: "QuestionGroups");
            migrationBuilder.DropTable(name: "Exams");

            migrationBuilder.RenameTable(name: "Exams_New", newName: "Exams");

            migrationBuilder.AddForeignKey(
                name: "FK_ToeicQuestions_Exams_ExamID",
                table: "ToeicQuestions",
                column: "ExamID",
                principalTable: "Exams",
                principalColumn: "ExamID",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.CreateIndex(
                name: "IX_ToeicQuestions_ExamID",
                table: "ToeicQuestions",
                column: "ExamID");
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_ToeicQuestions_Exams_ExamID",
                table: "ToeicQuestions");
            migrationBuilder.DropIndex(
                name: "IX_ToeicQuestions_ExamID",
                table: "ToeicQuestions");

            migrationBuilder.CreateTable(
                name: "Exams_Old",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Name = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: false),
                    DurationMinutes = table.Column<int>(type: "int", nullable: false),
                    TotalQuestions = table.Column<int>(type: "int", nullable: false),
                    IsPublished = table.Column<bool>(type: "bit", nullable: false),
                    CreationTime = table.Column<DateTime>(type: "datetime2", nullable: false),
                    CreatorUserId = table.Column<long>(type: "bigint", nullable: true),
                    LastModificationTime = table.Column<DateTime>(type: "datetime2", nullable: true),
                    LastModifierUserId = table.Column<long>(type: "bigint", nullable: true),
                    IsDeleted = table.Column<bool>(type: "bit", nullable: false),
                    DeleterUserId = table.Column<long>(type: "bigint", nullable: true),
                    DeletionTime = table.Column<DateTime>(type: "datetime2", nullable: true),
                    StartAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    EndAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    DeleteAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    OriginalFileName = table.Column<string>(type: "nvarchar(260)", maxLength: 260, nullable: true),
                    OriginalDocument = table.Column<byte[]>(type: "varbinary(max)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Exams_Old", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "QuestionGroups",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    ExamId = table.Column<long>(type: "bigint", nullable: false),
                    Part = table.Column<int>(type: "int", nullable: false),
                    OrderIndex = table.Column<int>(type: "int", nullable: false),
                    Content = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    ImageUrl = table.Column<string>(type: "nvarchar(max)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_QuestionGroups", x => x.Id);
                    table.ForeignKey(
                        name: "FK_QuestionGroups_Exams_Old_ExamId",
                        column: x => x.ExamId,
                        principalTable: "Exams_Old",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "Questions",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    QuestionGroupId = table.Column<long>(type: "bigint", nullable: false),
                    Number = table.Column<int>(type: "int", nullable: false),
                    Text = table.Column<string>(type: "nvarchar(max)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Questions", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Questions_QuestionGroups_QuestionGroupId",
                        column: x => x.QuestionGroupId,
                        principalTable: "QuestionGroups",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "QuestionOptions",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    QuestionId = table.Column<long>(type: "bigint", nullable: false),
                    Label = table.Column<string>(type: "nvarchar(1)", maxLength: 1, nullable: false),
                    Text = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    IsCorrect = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_QuestionOptions", x => x.Id);
                    table.ForeignKey(
                        name: "FK_QuestionOptions_Questions_QuestionId",
                        column: x => x.QuestionId,
                        principalTable: "Questions",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(name: "IX_QuestionGroups_ExamId", table: "QuestionGroups", column: "ExamId");
            migrationBuilder.CreateIndex(name: "IX_Questions_QuestionGroupId", table: "Questions", column: "QuestionGroupId");
            migrationBuilder.CreateIndex(name: "IX_QuestionOptions_QuestionId", table: "QuestionOptions", column: "QuestionId");

            migrationBuilder.Sql(
                """
                SET IDENTITY_INSERT dbo.Exams_Old ON;
                INSERT INTO dbo.Exams_Old
                    (Id, Name, DurationMinutes, TotalQuestions, IsPublished, CreationTime,
                     CreatorUserId, LastModificationTime, LastModifierUserId, IsDeleted,
                     DeleterUserId, DeletionTime, StartAt, EndAt, DeleteAt, OriginalFileName, OriginalDocument)
                SELECT
                    ExamID, ExamName, TimeLimitMinutes, TotalQuestions,
                    CASE WHEN EndTime > GETDATE() AND EndTime > StartTime THEN 1 ELSE 0 END,
                    COALESCE(CONVERT(DATETIME2, CreatedAt), SYSUTCDATETIME()),
                    NULL, NULL, NULL, 0, NULL, NULL,
                    CASE WHEN StartTime = CONVERT(DATETIME, '17530101', 112)
                                   AND EndTime = CONVERT(DATETIME, '17530101', 112)
                         THEN NULL ELSE CONVERT(DATETIME2, StartTime) END,
                    CASE WHEN StartTime = CONVERT(DATETIME, '17530101', 112)
                                   AND EndTime = CONVERT(DATETIME, '17530101', 112)
                         THEN NULL ELSE CONVERT(DATETIME2, EndTime) END,
                    NULL, NULL, NULL
                FROM dbo.Exams;
                SET IDENTITY_INSERT dbo.Exams_Old OFF;

                ;WITH PassageGroups AS
                (
                    SELECT ExamID, PassageText, MIN(QuestionID) AS FirstQuestionID
                    FROM dbo.ToeicQuestions
                    GROUP BY ExamID, PassageText
                ),
                OrderedGroups AS
                (
                    SELECT ExamID, PassageText,
                        ROW_NUMBER() OVER (PARTITION BY ExamID ORDER BY FirstQuestionID) AS GroupOrder
                    FROM PassageGroups
                )
                INSERT INTO dbo.QuestionGroups (ExamId, Part, OrderIndex, Content)
                SELECT ExamID, 7, GroupOrder, PassageText FROM OrderedGroups;

                SET IDENTITY_INSERT dbo.Questions ON;
                INSERT INTO dbo.Questions (Id, QuestionGroupId, Number, Text)
                SELECT source.QuestionID, qg.Id,
                    100 + ROW_NUMBER() OVER (PARTITION BY source.ExamID ORDER BY source.QuestionID),
                    source.QuestionText
                FROM dbo.ToeicQuestions AS source
                INNER JOIN dbo.QuestionGroups AS qg
                    ON qg.ExamId = source.ExamID
                    AND (qg.Content = source.PassageText
                         OR (qg.Content IS NULL AND source.PassageText IS NULL));
                SET IDENTITY_INSERT dbo.Questions OFF;

                INSERT INTO dbo.QuestionOptions (QuestionId, Label, Text, IsCorrect)
                SELECT source.QuestionID, options.Label, options.OptionText,
                    CASE WHEN source.CorrectAnswer = options.CorrectValue THEN 1 ELSE 0 END
                FROM dbo.ToeicQuestions AS source
                CROSS APPLY (VALUES
                    (N'A', source.Option1, 1), (N'B', source.Option2, 2),
                    (N'C', source.Option3, 3), (N'D', source.Option4, 4)
                ) AS options(Label, OptionText, CorrectValue);

                DROP TABLE dbo.ToeicQuestions;
                """);

            migrationBuilder.DropTable(name: "Exams");
            migrationBuilder.RenameTable(name: "Exams_Old", newName: "Exams");
        }
    }
}
