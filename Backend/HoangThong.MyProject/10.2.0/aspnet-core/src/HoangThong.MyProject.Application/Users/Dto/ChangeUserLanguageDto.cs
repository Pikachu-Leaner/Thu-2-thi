using System.ComponentModel.DataAnnotations;

namespace HoangThong.MyProject.Users.Dto;

public class ChangeUserLanguageDto
{
    [Required]
    public string LanguageName { get; set; }
}