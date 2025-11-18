# Hebrew RSS Reader for Tidbyt (Ynet-Friendly)

This is a Pixlet / Tidbyt applet that displays **Hebrew RSS headlines** in the
correct **right-to-left (RTL)** direction on a Tidbyt device.

It is optimized for feeds like **Ynet**:

- Hebrew headlines are:
  - Normalized so **final letters** (ך ם ן ף ץ) become their regular forms
    (כ מ נ פ צ) to avoid `?` glyphs in the `tb-8` font.
  - **Reversed** in code so that, when rendered left-to-right, they appear
    visually **RTL** on the Tidbyt.
  - **Right-aligned** in a 64px-wide area.

- The **title bar** (feed name) is:
  - English / LTR
  - **Not reversed**
  - **Centered** using the `tom-thumb` font

---

## Requirements

- [Pixlet](https://github.com/tidbyt/pixlet) installed
- A Tidbyt device (optional but intended)
- A Hebrew RSS feed, for example:

```text
https://www.ynet.co.il/Integration/StoryRss2.xml