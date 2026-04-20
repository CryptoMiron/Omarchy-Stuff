package main

import "strings"

const convertedMatchPenalty int32 = 15

type searchVariant struct {
	Query   string
	Penalty int32
}

var enToRuKeymap = map[rune]rune{
	'`': 'ё',
	'q': 'й', 'w': 'ц', 'e': 'у', 'r': 'к', 't': 'е', 'y': 'н', 'u': 'г', 'i': 'ш', 'o': 'щ', 'p': 'з',
	'[': 'х', ']': 'ъ', 'a': 'ф', 's': 'ы', 'd': 'в', 'f': 'а', 'g': 'п', 'h': 'р', 'j': 'о', 'k': 'л',
	'l': 'д', ';': 'ж', '\'': 'э', 'z': 'я', 'x': 'ч', 'c': 'с', 'v': 'м', 'b': 'и', 'n': 'т', 'm': 'ь',
	',': 'б', '.': 'ю', '/': '.',
}

var ruToEnKeymap = map[rune]rune{
	'ё': '`',
	'й': 'q', 'ц': 'w', 'у': 'e', 'к': 'r', 'е': 't', 'н': 'y', 'г': 'u', 'ш': 'i', 'щ': 'o', 'з': 'p',
	'х': '[', 'ъ': ']', 'ф': 'a', 'ы': 's', 'в': 'd', 'а': 'f', 'п': 'g', 'р': 'h', 'о': 'j', 'л': 'k',
	'д': 'l', 'ж': ';', 'э': '\'', 'я': 'z', 'ч': 'x', 'с': 'c', 'м': 'v', 'и': 'b', 'т': 'n', 'ь': 'm',
	'б': ',', 'ю': '.', '.': '/',
}

func convertLayout(input string, keymap map[rune]rune) string {
	var builder strings.Builder
	builder.Grow(len(input))

	for _, r := range strings.ToLower(input) {
		if mapped, ok := keymap[r]; ok {
			builder.WriteRune(mapped)
			continue
		}

		builder.WriteRune(r)
	}

	return builder.String()
}

func buildQueryVariants(query string) []searchVariant {
	variants := []searchVariant{{Query: strings.ToLower(query), Penalty: 0}}
	seen := map[string]struct{}{strings.ToLower(query): {}}

	for _, candidate := range []string{
		convertLayout(query, enToRuKeymap),
		convertLayout(query, ruToEnKeymap),
	} {
		candidate = strings.ToLower(candidate)
		if _, ok := seen[candidate]; ok {
			continue
		}

		seen[candidate] = struct{}{}
		variants = append(variants, searchVariant{Query: candidate, Penalty: convertedMatchPenalty})
	}

	return variants
}
