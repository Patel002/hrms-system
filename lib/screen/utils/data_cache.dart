class DataCache {
  static final Map<String, Map<String, dynamic>> _userCache = {};

  static dynamic get(String userId, String key) => _userCache[userId]?[key];

  static void set(String userId, String key, dynamic value) {
    _userCache.putIfAbsent(userId, () => {});
    _userCache[userId]![key] = value;
  }

  static bool has(String userId, String key) => _userCache[userId]?.containsKey(key) ?? false;

  static void clear(String userId) {
    _userCache.remove(userId);
  }
}
