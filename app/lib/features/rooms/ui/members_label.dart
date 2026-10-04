String? membersLabel(int count) => switch (count) {
  <= 0 => null,
  1 => '1 membro',
  _ => '$count membros',
};
