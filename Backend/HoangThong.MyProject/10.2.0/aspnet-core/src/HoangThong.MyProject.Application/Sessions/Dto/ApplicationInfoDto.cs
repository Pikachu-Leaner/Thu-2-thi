using System;
using System.Collections.Generic;

namespace HoangThong.MyProject.Sessions.Dto;

public class ApplicationInfoDto
{
    public string Version { get; set; }

    public DateTime ReleaseDate { get; set; }

    public Dictionary<string, bool> Features { get; set; }
}
