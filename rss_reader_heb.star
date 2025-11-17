# RSS Reader with basic Hebrew RTL detection (codepoint-based)

load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")
load("xpath.star", "xpath")

# cache data for 15 minutes
CACHE_TTL_SECONDS = 900

DEFAULT_FEED_URL = "https://discuss.tidbyt.com/latest.rss"
DEFAULT_ARTICLE_COUNT = "3"
DEFAULT_FEED_NAME = "Tidbyt Forums"
DEFAULT_TITLE_COLOR = "#db7e35"
DEFAULT_TITLE_BG_COLOR = "#333333"
DEFAULT_ARTICLE_COLOR = "#65d1e6"
DEFAULT_SHOW_CONTENT = False
DEFAULT_CONTENT_COLOR = "#ff8c00"
DEFAULT_FONT = "tom-thumb"


def is_hebrew(text):
    """
    Detect Hebrew based on code points (Unicode / 'ASCII code'):
    Basic Hebrew block: U+0590–U+05FF == 1424–1535
    """
    if text == None:
        return False

    s = str(text)
    n = len(s)

    for i in range(n):
        ch = s[i]
        code = ord(ch)
        if code >= 1424 and code <= 1535:
            return True

    return False


def reverse_text(s):
    """
    Reverse a string using range(), since we can't use Python slicing with a step.
    """
    out = ""
    # range(start, stop, step) – walk backwards from len(s)-1 down to 0
    for i in range(len(s) - 1, -1, -1):
        out = out + s[i]
    return out


def make_wrapped_text(text, color, font):
    """
    Build a WrappedText widget that:
    - Detects Hebrew via is_hebrew()
    - If Hebrew: reverse + right-align
    - Else: normal + left-align
    """
    if text == None:
        s = ""
    else:
        s = str(text).strip()

    if is_hebrew(s):
        s = reverse_text(s)
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


def main(config):
    """Main app method."""

    # get config values (same IDs as original app)
    feed_url = config.get("feed_url", DEFAULT_FEED_URL)
    feed_name = config.get("feed_name", DEFAULT_FEED_NAME)
    title_color = config.get("title_color", DEFAULT_TITLE_COLOR)
    title_bg_color = config.get("title_bg_color", DEFAULT_TITLE_BG_COLOR)
    article_count = int(config.get("article_count", DEFAULT_ARTICLE_COUNT))
    article_color = config.get("article_color", DEFAULT_ARTICLE_COLOR)
    show_content = config.bool("show_content", DEFAULT_SHOW_CONTENT)
    content_color = config.get("content_color", DEFAULT_CONTENT_COLOR)
    font = config.get("font", DEFAULT_FONT)

    # if feed name is empty, show as "RSS Feed"
    if str(feed_name).strip() == "":
        feed_name = "RSS Feed"

    # if feed url is empty, use default
    if str(feed_url).strip() == "":
        feed_url = DEFAULT_FEED_URL

    # get feed articles
    articles = get_feed(feed_url, article_count)

    # Title bar: also Hebrew-aware
    title_text = str(feed_name).strip()
    if is_hebrew(title_text):
        title_text = reverse_text(title_text)
        title_align = "right"
    else:
        title_align = "left"

    return render.Root(
        delay = 100,
        show_full_animation = True,
        child = render.Column(
            children = [
                render.Box(
                    width = 64,
                    height = 8,
                    color = title_bg_color,
                    child = render.Text(
                        title_text,
                        color = title_color,
                        font = "tom-thumb",
                        align = title_align,
                    ),
                ),
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
    """Renders the widgets to display the articles."""

    article_text = []

    for article in articles:
        title = article[0]
        body = article[1]

        # Title: Hebrew-aware
        article_text.append(
            make_wrapped_text(title, article_color, font)
        )

        # Optional body: also Hebrew-aware
        if show_content:
            article_text.append(
                make_wrapped_text(body, content_color, font)
            )

        # Spacer between articles
        article_text.append(
            render.Box(width = 64, height = 8, color = "#000000")
        )

    return article_text


def get_feed(url, article_count):
    """Retrieves an RSS feed and builds a list with article titles and content."""

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
        articles.append(
            (
                data_xml.query(title_query),
                str(data_xml.query(desc_query)).replace("None", ""),
            )
        )

    return articles


def get_schema():
    """Creates the schema for the configuration screen."""

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
    )1(