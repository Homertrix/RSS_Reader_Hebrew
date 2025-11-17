"""
Applet: RSS Reader (Hebrew-aware)
Summary: RSS Feed Reader
Description: Displays entries from an RSS feed URL, with basic Hebrew RTL handling.
Author: Homertrix (Hebrew/RTL tweaks by ChatGPT)
"""

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

# ------------------------------------------------------------
# Hebrew detection based on code points ("ASCII code")
# ------------------------------------------------------------

def is_hebrew(text):
    """
    Returns True if the string contains any character in the Hebrew
    Unicode ranges (approx. "ASCII code" check).

    Hebrew block: 0x0590–0x05FF
    Hebrew Presentation Forms: 0xFB1D–0xFB4F
    """
    if text == None:
        return False

    s = str(text)
    n = len(s)

    i = 0
    while i < n:
        ch = s[i]
        code = ord(ch)
        if (code >= 0x0590 and code <= 0x05FF) or (code >= 0xFB1D and code <= 0xFB4F):
            return True
        i = i + 1

    return False


def reverse_string(s):
    """
    Reverse a string (no slicing step argument in Starlark).
    """
    out = ""
    i = len(s) - 1
    while i >= 0:
        out = out + s[i]
        i = i - 1
    return out


def make_wrapped_text(text, color, font):
    """
    Create a WrappedText widget that:
    - Detects Hebrew by codepoint.
    - If Hebrew, reverses the string and right-aligns it.
    - Otherwise, keeps the text as-is and left-aligns.
    """
    if text == None:
        s = ""
    else:
        s = str(text).strip()

    if is_hebrew(s):
        s = reverse_string(s)
        align = "right"
    else:
        align = "left"

    return render.WrappedText(
        s,
        color = color,
        font = font,
        width = 64,         # full Tidbyt width so alignment makes sense
        align = align,
    )

# ------------------------------------------------------------
# Main
# ------------------------------------------------------------

def main(config):
    """Main app method.

    Args:
        config (config): App configuration.

    Returns:
        render.Root: Root widget tree.
    """

    # get config values (same IDs as original)
    feed_url = config.get("feed_url", DEFAULT_FEED_URL)
    feed_name = config.get("feed_name", DEFAULT_FEED_NAME)
    title_color = config.get("title_color", DEFAULT_TITLE_COLOR)
    title_bg_color = config.get("title_bg_color", DEFAULT_TITLE_BG_COLOR)
    article_count = int(config.get("article_count", DEFAULT_ARTICLE_COUNT))
    article_color = config.get("article_color", DEFAULT_ARTICLE_COLOR)
    show_content = config.get("show_content", DEFAULT_SHOW_CONTENT)
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

    # Title bar: also Hebrew-aware (reverse + right-align if needed)
    title_text = str(feed_name).strip()
    if is_hebrew(title_text):
        title_text = reverse_string(title_text)
        title_align = "right"
    else:
        title_align = "left"

    # render view
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

# ------------------------------------------------------------
# Rendering articles
# ------------------------------------------------------------

def render_articles(articles, show_content, article_color, content_color, font):
    """Renders the widgets to display the articles.

    Args:
        articles (list): The list of articles to render.
        show_content (bool): Indicates if the article content should be rendered.
        article_color (str): Color of the article title.
        content_color (str): Color of the article content.

    Returns:
        list: List of widgets.
    """

    article_text = []

    for article in articles:
        title = article[0]
        body = article[1]

        # Title: Hebrew-aware
        article_text.append(
            make_wrapped_text(title, article_color, font)
        )

        if show_content:
            # Content: Hebrew-aware as well
            article_text.append(
                make_wrapped_text(body, content_color, font)
            )

        # Spacer between articles
        article_text.append(
            render.Box(width = 64, height = 8, color = "#000000")
        )

    return article_text

# ------------------------------------------------------------
# RSS fetching (same structure as original)
# ------------------------------------------------------------

def get_feed(url, article_count):
    """Retrieves an RSS feeds and builds a list with article's titles and content.

    Args:
        url (str): The RSS feed URL.
        article_count (int): The number of articles to retrieve from the feed.

    Returns:
        list: List of tuples with (article title, article content).
    """

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

# ------------------------------------------------------------
# Configuration schema (same fields as original)
# ------------------------------------------------------------

def get_schema():
    """Creates the schema for the configuration screen.

    Returns:
        schema.Schema: The schema for the configuration screen.
    """

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
    )
