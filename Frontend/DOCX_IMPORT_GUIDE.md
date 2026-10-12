# DOCX exam import requirements

The teacher portal imports a Word **`.docx`** file and immediately creates an
unpublished exam in SQL. The importer stores parsed question data but does not
retain the uploaded Word file. The exam is not visible to students until a
teacher sets its schedule and enables it. All tests use a 75-minute limit.

The importer reads paragraph text from the DOCX. It does not read questions
from screenshots, pictures, text boxes, headers, or footers. Put all import
content in the document body as selectable text. The uploaded file must be no
larger than 10 MB.

## Required question data

- Exactly 100 questions, numbered consecutively **101 through 200**.
- Begin Part 5 with the exact marker `{Part 5}`. Part 5 contains questions
  101–130.
- Begin Parts 6 and 7 with the exact marker `{Part 6,7}`. Use one
  `<passage>...</passage>` block before the questions that refer to that
  passage. Part 6 contains 131–146; Part 7 contains 147–200.
- Keep each passage's questions together and in ascending order. The app
  determines the displayed part from the question number and keeps each
  consecutive passage group together.
- Each question must use `<question>number. question text</question>`.
- Each question must have non-empty `<answer1>`, `<answer2>`, `<answer3>`, and
  `<answer4>` tags.
- Each question must have exactly one `<correct>` tag whose value is `1`, `2`,
  `3`, or `4`. The number points to the corresponding answer tag.
- Keep all non-passage content inside the recognized tags. Do not add
  untagged titles, instructions, page numbers, or separator lines between
  markup blocks.
- Plain text and punctuation should stay inside a recognized tag such as
  `<passage>`. Do not put nested markup-like tags inside the content.

Tag names are case-insensitive (`<QUESTION>` is accepted), but use the exact
lowercase spellings below for clarity. The Part markers should use the exact
`{Part 5}` and `{Part 6,7}` forms. Whitespace and blank paragraphs between
markup blocks are allowed.

## Format example

This shortened example uses the same tag structure as the supplied
`toeic_test06_data.docx`. It is **not upload-ready** because it contains only
six questions instead of the required 100.

```text
{Part 5}
<question>101. The manager ------- the report before the meeting.</question>
<answer1>review</answer1>
<answer2>reviews</answer2>
<answer3>reviewing</answer3>
<answer4>reviewed</answer4>
<correct>2</correct>

<question>102. Please submit the form ------- Friday.</question>
<answer1>by</answer1>
<answer2>with</answer2>
<answer3>during</answer3>
<answer4>among</answer4>
<correct>1</correct>

{Part 6,7}
<passage>
The staff meeting will begin at 9:00 A.M. in Conference Room B. Please bring a copy of the quarterly report.
The agenda will be sent by e-mail before the meeting. Additionally, employees should review the latest sales figures.
</passage>
<question>131. When will the meeting begin?</question>
<answer1>At 8:00 A.M.</answer1>
<answer2>At 9:00 A.M.</answer2>
<answer3>At noon</answer3>
<answer4>In the afternoon</answer4>
<correct>2</correct>

<question>132. Where will the meeting take place?</question>
<answer1>In a conference room</answer1>
<answer2>At a restaurant</answer2>
<answer3>At the main entrance</answer3>
<answer4>In the lobby</answer4>
<correct>3</correct>

<question>133. What should employees review?</question>
<answer1>The latest sales figures</answer1>
<answer2>The room reservation</answer2>
<answer3>The attendance policy</answer3>
<answer4>The travel schedule</answer4>
<correct>1</correct>

<question>134. What should attendees bring?</question>
<answer1>A building map</answer1>
<answer2>A printed copy of the quarterly report</answer2>
<answer3>A travel receipt</answer3>
<answer4>A visitor badge</answer4>
<correct>2</correct>
```

## How to prepare and import

1. Open a new or existing Word document and save it as **Word Document
   (`.docx`)**.
2. Add the Part 5 questions, then the Part 6/7 passages and questions, in
   ascending question-number order.
3. For each question, confirm it has four non-empty answer tags and a correct
   answer from 1 to 4. Check that the last question is 200.
4. Remove untagged headings and instructions from the document body. Keep
   passage wording, including headings that belong to the passage, inside its
   `<passage>` block.
5. In the teacher portal, choose **Import**, enter a test name, choose the DOCX,
   and confirm the import. A successful import appears immediately as a
   disabled draft with a 75-minute limit.
6. Open the imported test to edit/review its parsed questions. Use the numbered
   question pills to jump to a question; Parts 6 and 7 show their passage for
   editing. Set the start and end times, then enable it when it is ready for
   students.

The importer reports validation errors and does not save an invalid document.
