/// Curated story content is separate from game UI so every displayed reading
/// word can be checked against a known prerequisite set.
class MiniStoryPage {
  const MiniStoryPage({
    required this.text,
    required this.illustrationWordId,
  });

  final String text;
  final String illustrationWordId;
}

class MiniStory {
  const MiniStory({
    required this.id,
    required this.requiredGraphemes,
    required this.pages,
  });

  final String id;
  final Set<String> requiredGraphemes;
  final List<MiniStoryPage> pages;

  bool isAvailable(Set<String> taught) => taught.containsAll(requiredGraphemes);
}

/// Every word in these two pages is fully decodable once the prerequisite
/// graphemes have been introduced; no sight-word assumption is required.
const gardenFriendsStory = MiniStory(
  id: 'story:garden-friends',
  requiredGraphemes: {
    'g:s',
    'g:a',
    'g:t',
    'g:d',
    'g:m',
    'g:n',
  },
  pages: [
    MiniStoryPage(
      text: 'Sam sat.',
      illustrationWordId: 'w:man',
    ),
    MiniStoryPage(
      text: 'Dan and Sam sat.',
      illustrationWordId: 'w:dad',
    ),
  ],
);

/// The offline story catalog. A path stores the ID, not a reference to a
/// particular Dart constant, so downloaded lesson packs can add stories later.
const miniStories = <MiniStory>[gardenFriendsStory];

MiniStory? miniStoryForId(String id) {
  for (final story in miniStories) {
    if (story.id == id) return story;
  }
  return null;
}
