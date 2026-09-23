class ProfilePromptDefinition {
  const ProfilePromptDefinition({required this.id, required this.text});

  final String id;
  final String text;
}

class ProfilePromptLibrary {
  const ProfilePromptLibrary._();

  static const int requiredPromptCount = 3;
  static const int answerCharacterLimit = 150;

  static const prompts = [
    ProfilePromptDefinition(
      id: 'perfect_weekend',
      text: 'A perfect weekend for me is...',
    ),
    ProfilePromptDefinition(
      id: 'make_me_laugh',
      text: 'The quickest way to make me laugh is...',
    ),
    ProfilePromptDefinition(
      id: 'always_excited_to_talk_about',
      text: "Something I'm always excited to talk about...",
    ),
    ProfilePromptDefinition(
      id: 'ideal_first_date',
      text: 'My ideal first date...',
    ),
    ProfilePromptDefinition(
      id: 'small_happy_thing',
      text: 'A small thing that makes me happy...',
    ),
    ProfilePromptDefinition(
      id: 'looking_for_someone_who',
      text: "I'm looking for someone who...",
    ),
    ProfilePromptDefinition(
      id: 'one_thing_to_know',
      text: 'One thing you should know about me...',
    ),
    ProfilePromptDefinition(
      id: 'together_we_could',
      text: 'Together, we could...',
    ),
    ProfilePromptDefinition(
      id: 'friends_describe_me',
      text: 'My friends would describe me as...',
    ),
    ProfilePromptDefinition(
      id: 'goal_working_toward',
      text: "A goal I'm working toward...",
    ),
    ProfilePromptDefinition(
      id: 'simple_joy',
      text: 'My favorite simple joy is...',
    ),
    ProfilePromptDefinition(
      id: 'best_conversation',
      text: 'The best conversations usually include...',
    ),
    ProfilePromptDefinition(
      id: 'green_flag',
      text: 'A green flag I notice quickly...',
    ),
    ProfilePromptDefinition(
      id: 'learn_with_me',
      text: "Something I'd love to learn with someone...",
    ),
    ProfilePromptDefinition(
      id: 'feel_at_home',
      text: 'I feel most at home when...',
    ),
  ];

  static ProfilePromptDefinition? byId(String id) {
    for (final prompt in prompts) {
      if (prompt.id == id) {
        return prompt;
      }
    }
    return null;
  }

  static String labelFor(String id) => byId(id)?.text ?? 'Profile prompt';
}
