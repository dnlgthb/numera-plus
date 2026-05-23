enum CharacterType { mage, warrior, tiger }

extension CharacterTypeExt on CharacterType {
  String get displayName => switch (this) {
    CharacterType.mage => 'Minerva',
    CharacterType.warrior => 'Arthur',
    CharacterType.tiger => 'Neko',
  };

  String get title => switch (this) {
    CharacterType.mage => 'La Bruja',
    CharacterType.warrior => 'El Guerrero',
    CharacterType.tiger => 'El Tigre',
  };

  bool get isFeminine => switch (this) {
    CharacterType.mage => true,
    CharacterType.warrior => false,
    CharacterType.tiger => false,
  };

  String get folder => switch (this) {
    CharacterType.mage => 'mage2',
    CharacterType.warrior => 'warrior',
    CharacterType.tiger => 'tiger',
  };

  String get prefix => switch (this) {
    CharacterType.mage => 'mage2',
    CharacterType.warrior => 'warrior',
    CharacterType.tiger => 'tiger',
  };

  String spritePath(String pose) => 'assets/sprites/$folder/${prefix}_$pose.png';

  bool get naturallyFacesLeft => switch (this) {
    CharacterType.mage => true,
    CharacterType.warrior => true,
    CharacterType.tiger => true,
  };
}
