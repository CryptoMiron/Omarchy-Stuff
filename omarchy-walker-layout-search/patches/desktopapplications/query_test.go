package main

import "testing"

func testConfig() *Config {
	return &Config{OnlySearchTitle: false}
}

func TestCalcScoreMatchesEnglishNameFromRussianLayout(t *testing.T) {
	config = testConfig()
	data := &Data{Name: "firefox", GenericName: "browser", Comment: "web browser"}

	match, score, _, _, ok := calcScore("ашкуащч", data, false)
	if !ok {
		t.Fatal("expected converted russian layout query to match firefox")
	}

	if match != "firefox" {
		t.Fatalf("expected firefox match, got %q", match)
	}

	if score <= 0 {
		t.Fatalf("expected positive score, got %d", score)
	}
}

func TestCalcScoreMatchesRussianNameFromEnglishLayout(t *testing.T) {
	config = testConfig()
	data := &Data{Name: "терминал", GenericName: "terminal"}

	match, score, _, _, ok := calcScore("nthvbyfk", data, false)
	if !ok {
		t.Fatal("expected converted english layout query to match russian name")
	}

	if match != "терминал" {
		t.Fatalf("expected терминал match, got %q", match)
	}

	if score <= 0 {
		t.Fatalf("expected positive score, got %d", score)
	}
}

func TestCalcScorePrefersDirectMatchOverConvertedMatch(t *testing.T) {
	config = testConfig()
	data := &Data{Name: "firefox"}

	_, directScore, _, _, directOK := calcScore("firefox", data, false)
	_, convertedScore, _, _, convertedOK := calcScore("ашкуащч", data, false)

	if !directOK || !convertedOK {
		t.Fatalf("expected both direct and converted queries to match: direct=%t converted=%t", directOK, convertedOK)
	}

	if directScore <= convertedScore {
		t.Fatalf("expected direct score %d to exceed converted score %d", directScore, convertedScore)
	}
}

func TestCalcScoreStillSearchesNonTitleFields(t *testing.T) {
	config = testConfig()
	data := &Data{Name: "org.example.browser", GenericName: "браузер", Comment: "просмотр веб-страниц"}

	match, _, _, _, ok := calcScore("браузер", data, false)
	if !ok {
		t.Fatal("expected generic name to remain searchable")
	}

	if match != "браузер" {
		t.Fatalf("expected generic name match, got %q", match)
	}
}
