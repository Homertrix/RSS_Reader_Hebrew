# RSS Reader with Hebrew RTL support
# - Detects Hebrew by Unicode codepoints (0x0590–0x05FF)
# - If Hebrew:
#     * always right-align
#     * optional reversal controlled by config flag rtl_reverse
# - Non-Hebrew stays left-aligned and unreversed

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
DEFAULT_FONT = "tom-thumb"
DEFAULT_RTL_REVERSE = False   # default: do NOT reverse Hebrew, only right-align


# ---- Hebrew detection using Unicode codepoints ("ASCII code") ----

def is_hebrew(text):
    # Detect Hebrew based on Unicode code points:
    # Basic Hebrew block: U+0590–U+05FF
    if text == None:
        return False

    s = str(text)
    n = len(s)

    for i in range(n):
        ch = s[i]
        code = ord(ch)
        # 0x0590–0x05FF (1424–1535)
        if code >= 0x0590 and code <= 0x05FF:
            return True

    return False


def reverse_text(s):
    # Reverse string using a backwards for loop
    out = ""
    for i in range(len(s) - 1, -1, -1):
        out = out + s[i]
    return out


def make_wrapped_text(text, color, font, rtl_reverse):
    # Wrap text and apply Hebrew RTL behavior:
    # - If Hebrew: always right-align, optional reverse if rtl_reverse is True
    # - If not Hebrew: left-align, no reverse
    if text == None:
        s = ""
    else:
        s = str(text).strip()

    heb = is_hebrew(s)

    if heb and rtl_reverse:
        s = reverse_text(s)

    if heb:
        align = "right"
    else:
        align = "left"

    return render.WrappedText(
        s,
        color = color,
        font = font,
        width = 64,
        align = align,
    )


# ---- Main app ----

def main(config):
    # Get config values (same IDs as original app, plus rtl_reverse)
    feed_url = config.get("feed_url", DEFAULT_FEED_URL)
    feed_name = config.get("feed_name", DEFAULT_FEED_NAME)
    title_color = config.get("title_color", DEFAULT_TITLE_COLOR)
    title_bg_color = config.get("title_bg_color", DEFAULT_TITLE_BG_COLOR)
    article_count = int(config.get("article_count", DEFAULT_ARTICLE_COUNT))
    article_color = config.get("article_color", DEFAULT_ARTICLE_COLOR)
    show_content = config.bool("show_content", DEFAULT_SHOW_CONTENT)
    content_color = config.get("content_color", DEFAULT_CONTENT_COLOR)
    font = config.get("font", DEFAULT_FONT)
    rtl_reverse = config.bool("rtl_reverse", DEFAULT_RTL_REVERSE)

    # Fallbacks
    if str(feed_name).strip() == "":
        feed_name = "RSS Feed"

    if str(feed_url).strip() == "":
        feed_url = DEFAULT_FEED_URL

    # Get feed articles
    articles = get_feed(feed_url, article_count)

    # Title text (same RTL behavior)
    title_text = str(feed_name).strip()

    return render.Root(
        delay = 100,
        show_full_animation = True,
        child = render.Column(
            children = [
                # Header bar
                render.Box(
                    width = 64,
                    height = 8,
                    color = title_bg_color,
                    child = make_wrapped_text(
                        title_text,
                        title_color,
                        "tom-thumb",  # small font for header
                        rtl_reverse,
                    ),
                ),
                # Scrolling list of articles
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
                            rtl_reverse,
                        ),
                    ),
                ),
            ],
        ),
    )


def render_articles(articles, show_content, article_color, content_color, font, rtl_reverse):
    # Build list of article widgets
    article_text = []

    for article in articles:
        title = article[0]
        body = article[1]

        # Title: Hebrew-aware (align + optional reverse)
        article_text.append(
            make_wrapped_text(title, article_color, font, rtl_reverse)
        )

        # Optional content: also Hebrew-aware
        if show_content:
            article_text.append(
                make_wrapped_text(body, content_color, font, rtl_reverse)
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
    # Configuration schema (same as original app + RTL toggle)
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
                desc = "The name of the RSS feed.",
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
                desc = "Font size for text.",
                icon = "textHeight",
                default = DEFAULT_FONT,
                options = [
                    schema.Option(display = "Default", value = DEFAULT_FONT),
                    schema.Option(display = "Larger", value = "tb-8"),
                ],
            ),
            schema.Toggle(
                id = "show_content",
                name = "Show Article Content",
                desc = "Show the article's content.",
                icon = "toggleOff",
                default = DEFAULT_SHOW_CONTENT,
            ),
            schema.Toggle(
                id = "rtl_reverse",
                name = "Reverse Hebrew text",
                desc = "If enabled, reverse Hebrew strings before drawing.",
                icon = "toggleOff",
                default = DEFAULT_RTL_REVERSE,
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