using System.Threading.Tasks;
using Abp.Authorization;
using HoangThong.MyProject.Controllers;
using HoangThong.MyProject.Exams.Import;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace HoangThong.MyProject.Web.Host.Controllers;

/// <summary>Accepts teacher DOCX exam uploads.</summary>
[ApiController]
[Route("api/exams")]
[AbpAllowAnonymous]
public class ExamImportController : MyProjectControllerBase
{
    private readonly IExamImportService _examImportService;

    /// <summary>Validates and saves a DOCX Reading exam.</summary>
    public ExamImportController(IExamImportService examImportService)
    {
        _examImportService = examImportService;
    }

    /// <summary>Imports a DOCX file containing questions 101 through 200.</summary>
    [HttpPost("import")]
    [RequestSizeLimit(10 * 1024 * 1024)]
    public async Task<IActionResult> Import(
        [FromForm] string name,
        [FromForm] IFormFile file)
    {
        if (file == null || file.Length == 0)
        {
            return BadRequest(new { error = new { message = "Choose a non-empty DOCX file." } });
        }

        await using var stream = file.OpenReadStream();
        var result = await _examImportService.ImportAsync(name, stream);
        if (result.Errors.Count > 0)
        {
            return BadRequest(new { error = new { message = string.Join("\n", result.Errors) } });
        }

        return Ok(new { result = new { examId = result.ExamId, errors = result.Errors } });
    }
}
