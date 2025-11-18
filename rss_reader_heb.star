# RSS Reader - Hebrew RTL headlines + centered English title
# - Headlines: normalize finals -> reverse + right-align (for Hebrew feeds like Ynet)
# - Title (feed_name): English/LTR, not reversed, centered in header bar

load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")
load("xpath.star", "xpath")

# Cache data for 15 minutes
CACHE_TTL_SECONDS = 900

# Defaults
DEFAULT_FEED_URL = "https://discuss.tidbyt.com/latest.rss"
DEFAULT_FEED_NAME = "Tidbyt Forums"
DEFAULT_ARTICLE_COUNT = "3"
DEFAULT_TITLE_COLOR = "#db7e35"
DEFAULT_TITLE_BG_COLOR = "#333333"
DEFAULT_ARTICLE_COLOR = "#65d1e6"
DEFAULT_SHOW_CONTENT = False
DEFAULT_CONTENT_COLOR = "#ff8c00"

# Use tb-8 as default so Hebrew shows
DEFAULT_FONT = "tb-8"


def normalize_hebrew_finals(text):
    """
    Replace Hebrew final letters with their regular forms to avoid '?' glyphs
    if the font doesn't support finals:
      ך -> כ
      ם -> מ
      ן -> נ
      ף -> פ
      ץ -> צ
    """
    if text == None:
        return ""

    s = str(text)
    out = ""

    for i in range(len(s)):
        ch = s[i]
        code = ord(ch)

        # ך (0x05DA) -> כ (0x05DB)
        if code == 0x05DA:
            out = out + u"\u05DB"
        # ם (0x05DD) -> מ (0x05DE)
        elif code == 0x05DD:
            out = out + u"\u05DE"
        # ן (0x05DF) -> נ (0x05E0)
        elif code == 0x05DF:
            out = out + u"\u05E0"
        # ף (0x05E3) -> פ (0x05E4)
        elif code == 0x05E3:
            out = out + u"\u05E4"
        # ץ (0x05E5) -> צ (0x05E6)
        elif code == 0x05E5:
            out = out + u"\u05E6"
        else:
            out = out + ch

    return out


def reverse_text(s):
    # Reverse string using a backwards for loop
    out = ""
    for i in range(len(s) - 1, -1, -1):
        out = out + s[i]
    return out


def make_headline_text(text, color, font):
    """
    Headlines/content for Hebrew feeds:
      - normalize Hebrew final letters -> regular forms
      - reverse the normalized string
      - right-align
    Assumes feed is mostly Hebrew (e.g., Ynet).
    """
    # Normalize finals first (avoid '?')
    s = normalize_hebrew_finals(text)
    # Then reverse for visual RTL on Tidbyt
    s = reverse_text(s)

    return render.WrappedText(
        s,
        color = color,
        font = font,
        width = 64,
        align = "right",
    )


def make_centered_title(text, color):
    """
    Applet title (feed_name):
      - use as-is (LTR)
      - not reversed
      - centered in 64px width
      - tom-thumb font for header
    """
    if text == None:
        s = ""
    else:
        s = str(text).strip()

    return render.WrappedText(
        s,
        color = color,
        font = "tom-thumb",
        width = 64,
        align = "center",
    )


def main(config):
    # Get config values
    feed_url = config.get("feed_url", DEFAULT_FEED_URL)
    feed_name = config.get("feed_name", DEFAULT_FEED_NAME)
    title_color = config.get("title_color", DEFAULT_TITLE_COLOR)
    title_bg_color = config.get("title_bg_color", DEFAULT_TITLE_BG_COLOR)
    article_count = int(config.get("article_count", DEFAULT_ARTICLE_COUNT))
    article_color = config.get("article_color", DEFAULT_ARTICLE_COLOR)
    show_content = config.bool("show_content", DEFAULT_SHOW_CONTENT)
    content_color = config.get("content_color", DEFAULT_CONTENT_COLOR)
    font = config.get("font", DEFAULT_FONT)  # default is tb-8

    # Fallbacks
    if str(feed_name).strip() == "":
        feed_name = "RSS Feed"

    if str(feed_url).strip() == "":
        feed_url = DEFAULT_FEED_URL

    # Get feed articles
    articles = get_feed(feed_url, article_count)

    # Title text: English / LTR, centered
    title_text = feed_name

    return render.Root(
        delay = 100,
        show_full_animation = True,
        child = render.Column(
            children = [
                # Header bar with centered English title
                render.Box(
                    width = 64,
                    height = 8,
                    color = title_bg_color,
                    child = make_centered_title(
                        title_text,
                        title_color,
                    ),
                ),
                # Scrolling list of Hebrew headlines
                render.Marquee(
                    height = 24,
                    scroll_direction = "vertical",
                    offset_start = 24,
                    child = render.Column(
                        main_align = "space_between",
                        children = render_articles(
                            articles,
                            show_content,
                            article_color,
                            content_color,
                            font,
                        ),
                    ),
                ),
            ],
        ),
    )


def render_articles(articles, show_content, article_color, content_color, font):
    # Build list of article widgets
    article_text = []

    for article in articles:
        title = article[0]
        body = article[1]

        # Title/headline: normalize finals -> reverse + right-align
        article_text.append(
            make_headline_text(title, article_color, font)
        )

        # Optional content: same RTL treatment
        if show_content:
            article_text.append(
                make_headline_text(body, content_color, font)
            )

        # Spacer between articles
        article_text.append(
            render.Box(width = 64, height = 8, color = "#000000")
        )

    return article_text


def get_feed(url, article_count):
    # Retrieve RSS feed items
    res = http.get(url = url, ttl_seconds = CACHE_TTL_SECONDS)
    if res.status_code != 200:
        fail(
            "Request to %s failed with status code: %d: %s"
            % (url, res.status_code, res.body())
        )

    articles = []
    data_xml = xpath.loads(res.body())

    for i in range(1, article_count + 1):
        title_query = "//item[%s]/title" % str(i)
        desc_query = "//item[%s]/description" % str(i)

        title_raw = data_xml.query(title_query)
        desc_raw = str(data_xml.query(desc_query)).replace("None", "")

        articles.append((title_raw, desc_raw))

    return articles


def get_schema():
    # Configuration schema
    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(
                id = "feed_url",
                name = "RSS Feed URL",
                desc = "The URL of the RSS feed to display.",
                icon = "rss",
                default = DEFAULT_FEED_URL,
            ),
            schema.Text(
                id = "feed_name",
                name = "RSS Feed Name",
                desc = "The name of the RSS feed (English, shown centered).",
                icon = "font",
                default = DEFAULT_FEED_NAME,
            ),
            schema.Dropdown(
                id = "article_count",
                name = "Article Count",
                desc = "Number of articles to display",
                icon = "hashtag",
                default = "3",
                options = [
                    schema.Option(display = "1", value = "1"),
                    schema.Option(display = "2", value = "2"),
                    schema.Option(display = "3", value = "3"),
                    schema.Option(display = "4", value = "4"),
                    schema.Option(display = "5", value = "5"),
                ],
            ),
            schema.Dropdown(
                id = "font",
                name = "Text Size",
                desc = "Font size for headlines.",
                icon = "textHeight",
                default = DEFAULT_FONT,
                options = [
                    schema.Option(display = "Hebrew (tb-8)", value = "tb-8"),
                    schema.Option(display = "Small (tom-thumb)", value = "tom-thumb"),
                ],
            ),
            schema.Toggle(
                id = "show_content",
                name = "Show Article Content",
                desc = "Show the article's content (also RTL).",
                icon = "toggleOff",
                default = DEFAULT_SHOW_CONTENT,
            ),
            schema.Color(
                id = "title_color",
                name = "Feed Name Color",
                desc = "The color of the RSS feed name.",
                icon = "brush",
                default = DEFAULT_TITLE_COLOR,
            ),
            schema.Color(
                id = "title_bg_color",
                name = "Feed Name Background",
                desc = "The color of the RSS feed name background.",
                icon = "brush",
                default = DEFAULT_TITLE_BG_COLOR,
            ),
            schema.Color(
                id = "article_color",
                name = "Article Title Color",
                desc = "The color of the article's title.",
                icon = "brush",
                default = DEFAULT_ARTICLE_COLOR,
            ),
            schema.Color(
                id = "content_color",
                name = "Article Content Color",
                desc = "The color of the article's content.",
                icon = "brush",
                default = DEFAULT_CONTENT_COLOR,
            ),
        ],
    )