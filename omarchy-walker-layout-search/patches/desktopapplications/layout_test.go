package main

import (
	"slices"
	"testing"
)

func TestBuildQueryVariantsAddsConvertedLayouts(t *testing.T) {
	variants := buildQueryVariants("firefox")
	queries := make([]string, 0, len(variants))

	if len(variants) < 2 {
		t.Fatalf("expected original and converted variants, got %v", variants)
	}

	if variants[0].Query != "firefox" {
		t.Fatalf("expected original query first, got %q", variants[0].Query)
	}

	if variants[0].Penalty != 0 {
		t.Fatalf("expected original query penalty 0, got %d", variants[0].Penalty)
	}

	for _, variant := range variants {
		queries = append(queries, variant.Query)

		if variant.Query != "firefox" && variant.Penalty != convertedMatchPenalty {
			t.Fatalf("expected converted variant penalty %d, got %+v", convertedMatchPenalty, variant)
		}
	}

	if !slices.Contains(queries, "firefox") {
		t.Fatalf("expected original query in variants, got %v", queries)
	}

	if !slices.Contains(queries, "ашкуащч") {
		t.Fatalf("expected converted russian query in variants, got %v", queries)
	}
}

func TestBuildQueryVariantsDeduplicatesEquivalentQueries(t *testing.T) {
	variants := buildQueryVariants("123")
	if len(variants) != 1 {
		t.Fatalf("expected exactly one variant for non-letter input, got %d", len(variants))
	}
}

func TestConvertLayoutPreservesUnsupportedRunes(t *testing.T) {
	got := convertLayout("firefox-123", enToRuKeymap)
	if got != "ашкуащч-123" {
		t.Fatalf("expected converted query to preserve punctuation, got %q", got)
	}
}

func TestConvertLayoutSupportsRussianToEnglishPath(t *testing.T) {
	got := convertLayout("ашкуащч", ruToEnKeymap)
	if got != "firefox" {
		t.Fatalf("expected russian layout query to convert to english, got %q", got)
	}
}

func TestConvertLayoutMapsBacktickAndYo(t *testing.T) {
	if got := convertLayout("`test", enToRuKeymap); got != "ёеуые" {
		t.Fatalf("expected backtick to map to yo, got %q", got)
	}

	if got := convertLayout("ёеуые", ruToEnKeymap); got != "`test" {
		t.Fatalf("expected yo to map to backtick, got %q", got)
	}
}
