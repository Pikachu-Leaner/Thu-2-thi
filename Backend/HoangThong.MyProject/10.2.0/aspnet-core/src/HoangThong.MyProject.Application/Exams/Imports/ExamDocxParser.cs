using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Wordprocessing;

namespace HoangThong.MyProject.Exams.Import
{
    public class ParsedQuestion { public int Number; public string Text; public string[] Answers = new string[4]; public int Correct; }
    public class ParsedGroup { public string Passage; public List<ParsedQuestion> Questions = new List<ParsedQuestion>(); }
    public class ParsedExam { public List<ParsedGroup> Groups = new List<ParsedGroup>(); }

    public class ExamDocxParser
    {
        private static readonly Regex Token =
            new Regex(@"\{\s*Part\s*([^}]*)\}|<(\w+)>([\s\S]*?)</\2>", RegexOptions.Compiled);

        public ParsedExam Parse(Stream stream, List<string> errors)
        {
            var exam = new ParsedExam();
            string raw;
            try
            {
                using var doc = WordprocessingDocument.Open(stream, false);
                raw = string.Join("\n", doc.MainDocumentPart.Document.Body
                                          .Descendants<Paragraph>().Select(p => p.InnerText));
            }
            catch { errors.Add("The file is not a valid .docx document."); return exam; }

            int pos = 0; bool part5 = false, part67 = false;
            ParsedGroup group = null; ParsedQuestion q = null;

            void CloseOpen() { if (q != null) { errors.Add($"Question {q.Number}: missing <correct>."); q = null; } }

            foreach (Match m in Token.Matches(raw))
            {
                var gap = raw.Substring(pos, m.Index - pos).Trim();
                if (gap.Length > 0) errors.Add($"Unrecognized text or unclosed tag near: \"{Cut(gap)}\"");
                pos = m.Index + m.Length;

                if (m.Groups[1].Success)
                {
                    CloseOpen(); group = null;
                    var label = m.Groups[1].Value.Replace(" ", "");
                    part5 = label == "5"; part67 = label == "6,7";
                    if (!part5 && !part67) errors.Add($"Unknown part marker {{Part {label}}}.");
                    continue;
                }

                var tag = m.Groups[2].Value.ToLowerInvariant();
                var value = m.Groups[3].Value.Trim();

                switch (tag)
                {
                    case "passage":
                        CloseOpen();
                        if (!part67) errors.Add("<passage> is only allowed in {Part 6,7}.");
                        if (value.Length == 0) errors.Add("Empty <passage>.");
                        group = new ParsedGroup { Passage = value };
                        exam.Groups.Add(group);
                        break;

                    case "question":
                        CloseOpen();
                        var nm = Regex.Match(value, @"^\s*(\d+)\s*\.\s*(.+)$", RegexOptions.Singleline);
                        if (!nm.Success) { errors.Add($"Question must start with its number: \"{Cut(value)}\""); break; }
                        q = new ParsedQuestion { Number = int.Parse(nm.Groups[1].Value), Text = nm.Groups[2].Value.Trim() };
                        if (part5) { group = new ParsedGroup(); exam.Groups.Add(group); }
                        else if (group == null) { errors.Add($"Question {q.Number}: no <passage> before it."); group = new ParsedGroup(); exam.Groups.Add(group); }
                        group.Questions.Add(q);
                        break;

                    case "answer1": case "answer2": case "answer3": case "answer4":
                        if (q == null) errors.Add($"<{tag}> without a <question>.");
                        else if (value.Length == 0) errors.Add($"Question {q.Number}: <{tag}> is empty.");
                        else q.Answers[tag[6] - '1'] = value;
                        break;

                    case "correct":
                        if (q == null) { errors.Add("<correct> without a <question>."); break; }
                        for (int i = 0; i < 4; i++)
                            if (string.IsNullOrEmpty(q.Answers[i])) errors.Add($"Question {q.Number}: missing <answer{i + 1}>.");
                        if (!int.TryParse(value, out var c) || c < 1 || c > 4)
                            errors.Add($"Question {q.Number}: <correct> must be 1-4.");
                        else q.Correct = c;
                        q = null;
                        break;

                    default:
                        errors.Add($"Unknown tag <{tag}>."); break;
                }
            }

            if (raw.Substring(pos).Trim().Length > 0) errors.Add("Unrecognized text at the end of the file.");
            CloseOpen();

            var all = exam.Groups.SelectMany(g => g.Questions).ToList();
            if (all.Count != 100) errors.Add($"Expected 100 questions, found {all.Count}.");
            for (int i = 0; i < all.Count; i++)
                if (all[i].Number != 101 + i) { errors.Add($"Wrong numbering: expected {101 + i}, found {all[i].Number}."); break; }
            return exam;
        }

        private static string Cut(string s) => s.Length > 60 ? s.Substring(0, 60) + "…" : s;
    }
}