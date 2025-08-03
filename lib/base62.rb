class Base62
  # Randomized character set to make sequential codes unpredictable
  # This contains all 62 characters (0-9, A-Z, a-z) but in a random order
  CHARS = "RO9zDGxetiA5flHnXvU8M1WmJNqwhK6TaSVQjgPkIsFbc04pL7yoCurBdEZ32Y".freeze

  def self.encode(number)
    return CHARS[0] if number == 0  # Return first character instead of hardcoded "0"
    return nil if number < 0

    result = ""
    while number > 0
      result.prepend(CHARS[number % 62])
      number /= 62
    end
    result
  end
end
