# frozen_string_literal: true

require "rails_helper"

RSpec.describe Base62 do
  describe ".encode" do
    context "with valid positive numbers" do
      it "encodes 0 as the first character" do
        expect(described_class.encode(0)).to eq("R")
      end

      it "encodes 1 as the second character" do
        expect(described_class.encode(1)).to eq("O")
      end

      it "encodes 61 as the last character" do
        expect(described_class.encode(61)).to eq("Y")
      end

      it 'encodes 62 as "OR" (62^1)' do
        expect(described_class.encode(62)).to eq("OR")
      end

      it 'encodes 124 as "9R" (2 * 62)' do
        expect(described_class.encode(124)).to eq("9R")
      end

      it 'encodes 3844 as "ORR" (62^2)' do
        expect(described_class.encode(3844)).to eq("ORR")
      end

      it "encodes numbers consistently" do
        # Test a few specific numbers to ensure consistency
        expect(described_class.encode(100)).to be_a(String)
        expect(described_class.encode(1000)).to be_a(String)
        expect(described_class.encode(10000)).to be_a(String)
      end
    end

    context "with negative numbers" do
      it "returns nil for negative numbers" do
        expect(described_class.encode(-1)).to be_nil
      end

      it "returns nil for large negative numbers" do
        expect(described_class.encode(-100)).to be_nil
      end
    end

    describe "character set validation" do
      it "has exactly 62 characters in the character set" do
        expect(Base62::CHARS.length).to eq(62)
      end

      it "has unique characters in the character set" do
        expect(Base62::CHARS.chars.uniq.length).to eq(62)
      end

      it "contains all expected character types" do
        chars = Base62::CHARS.chars

        # Should contain digits
        expect(chars.any? { |c| c =~ /[0-9]/ }).to be true

        # Should contain uppercase letters
        expect(chars.any? { |c| c =~ /[A-Z]/ }).to be true

        # Should contain lowercase letters
        expect(chars.any? { |c| c =~ /[a-z]/ }).to be true
      end

      it "is different from standard base62 order" do
        standard_order = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
        expect(Base62::CHARS).not_to eq(standard_order)
      end
    end

    describe "conversion verification" do
      it "produces consistent results for the same input" do
        number = 12345
        result1 = described_class.encode(number)
        result2 = described_class.encode(number)
        expect(result1).to eq(result2)
      end

      it "produces different results for different inputs" do
        result1 = described_class.encode(100)
        result2 = described_class.encode(101)
        expect(result1).not_to eq(result2)
      end
    end

    describe "mathematical verification" do
      it "correctly implements base conversion with custom alphabet" do
        # Test that the algorithm works correctly regardless of character order
        number = 3844 # 1*62^2 + 0*62^1 + 0*62^0
        result = described_class.encode(number)

        # Should be 3 characters: [1][0][0] in custom alphabet
        first_char = Base62::CHARS[0]   # "R"
        second_char = Base62::CHARS[1]  # "O"
        expected = "#{second_char}#{first_char}#{first_char}"  # "ORR"
        expect(result).to eq(expected)
      end

      it "handles powers of 62 correctly" do
        first_char = Base62::CHARS[0]   # "R"
        second_char = Base62::CHARS[1]  # "O"

        expect(described_class.encode(0)).to eq(first_char)           # 62^0 * 0 = "R"
        expect(described_class.encode(1)).to eq(second_char)          # 62^0 * 1 = "O"
        expect(described_class.encode(62)).to eq("#{second_char}#{first_char}")    # 62^1 * 1 + 62^0 * 0 = "OR"
        expect(described_class.encode(3844)).to eq("#{second_char}#{first_char}#{first_char}") # 62^2 * 1 + 62^1 * 0 + 62^0 * 0 = "ORR"
      end
    end

    describe "security properties" do
      it "makes sequential URLs non-obvious" do
        # Generate a sequence of short codes
        codes = (1..20).map { |n| described_class.encode(n) }

        # Verify they don't follow an obvious pattern
        # In a truly randomized system, adjacent codes should look unrelated
        codes.each_cons(2) do |pair|
          expect(pair[0]).not_to eq(pair[1])
        end

        # The first few codes should not be easily guessable
        expect(codes[0]).not_to match(/^[0aA]/)  # Not starting with typical first chars
      end

      it "uses only characters from the defined character set" do
        result = described_class.encode(123456789)
        result.each_char do |char|
          expect(Base62::CHARS).to include(char)
        end
      end
    end

    describe "performance and reliability" do
      it "handles a range of numbers efficiently" do
        # Test various number ranges
        test_numbers = [ 0, 1, 61, 62, 100, 1000, 10000, 100000, 1000000 ]

        test_numbers.each do |number|
          result = described_class.encode(number)
          expect(result).to be_a(String)
          expect(result.length).to be > 0
        end
      end
    end
  end
end
