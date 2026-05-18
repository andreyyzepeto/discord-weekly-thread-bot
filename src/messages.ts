import fs from "node:fs";

export const DEFAULT_GUIDE_MESSAGE = `Please read the guidelines below and submit only one link per weekly feed boosting request.

Submission guidelines:
Your content must be high quality and follow the ZEPETO Community Guidelines. Sexual content, weapons, blood, and similar restricted content are not allowed.
Make sure your ZEPETO avatar is clearly visible on the cover feed.
Add relevant tags, including common tags such as #ZEPETO, #helloworld, #likeforlike, and #fyp where appropriate.
Unedited booth videos or photos will not be boosted.

A new weekly thread is posted every Monday. Previous threads may be locked, so please submit your request on time.

Thank you to all creators for making high-quality and engaging content. <:Blue_Badge:1331142137592545341>`;

export function loadGuideMessage(filePath: string): string {
  try {
    const content = fs.readFileSync(filePath, "utf8").trim();
    return content || DEFAULT_GUIDE_MESSAGE;
  } catch {
    return DEFAULT_GUIDE_MESSAGE;
  }
}
