# Substitution Cipher Decryption - Technical Report

## Executive Summary

This report documents the approach and results for cracking substitution ciphers using a **frequency analysis** combined with **simulated annealing** optimization technique. The method employs trigram frequency statistics from the English language to iteratively refine candidate decryption keys until an optimal solution is found.

---

## Approach and Methodology

### Overview

The cipher-cracking system uses a statistical approach based on the frequency of three-letter sequences (trigrams) in English text. The algorithm attempts to find the substitution key that produces the most "English-like" plaintext by maximizing the likelihood score based on trigram probabilities.

### 1. Cipher Characteristics

**Cipher Type:** Monoalphabetic Substitution Cipher

**Cipher Alphabet:**
```
1234567890@#$zyxwvutsrqpon
```
(26 characters total)

**Plain Alphabet:**
```
abcdefghijklmnopqrstuvwxyz
```
(26 characters total)

**Substitution Method:** Each character in the cipher alphabet maps to exactly one character in the plain alphabet, creating a one-to-one substitution scheme.

### 2. Trigram Frequency Analysis

#### Why Trigrams?

Trigrams (three-letter sequences) provide a robust statistical fingerprint of English text:
- More distinctive than single letters or bigrams
- Capture common word patterns and letter combinations
- Resistant to random fluctuations in short texts
- Balance between specificity and data availability

#### Trigram Database

The system uses a pre-compiled trigram frequency database (`trigram.txt`) containing:
- All three-letter combinations found in English text corpus
- Frequency counts for each trigram
- Converted to log-probabilities for computational efficiency

**Log-Probability Calculation:**
```
log_prob(trigram) = log₁₀(count(trigram) / total_count)
```

**Floor Value:** For unseen trigrams, a floor value is used:
```
floor = log₁₀(0.01 / total_count)
```

This ensures that rare or missing trigrams don't completely invalidate a candidate solution.

### 3. Scoring Mechanism

Each candidate plaintext is scored based on its trigram composition:

```python
def score(text):
    score = 0
    for each 3-letter sequence in text:
        score += log_prob(trigram) or floor
    return score
```

**Higher scores indicate more English-like text.**

The logarithmic approach allows:
- Efficient summation instead of multiplication
- Avoiding numerical underflow with tiny probabilities
- Natural handling of missing trigrams

### 4. Optimization Algorithm: Simulated Annealing

The system employs a **hill-climbing optimization** strategy with multiple random restarts:

#### Algorithm Steps:

1. **Initialization (Random Restart)**
   - Generate a random substitution key (permutation of the alphabet)
   - Decrypt the ciphertext using this key
   - Calculate initial trigram score

2. **Local Search (Hill Climbing)**
   - Randomly swap two characters in the key
   - Decrypt with the new key
   - Calculate new score
   - If score improves, keep the new key
   - If score doesn't improve, discard the change
   - Repeat for a fixed number of steps (3,000 iterations)

3. **Multiple Restarts**
   - Run the entire process 20 times with different random starting keys
   - Keep track of the best solution found across all restarts
   - Return the highest-scoring plaintext and its corresponding key

#### Why Multiple Restarts?

Hill climbing can get stuck in local optima. Multiple random restarts increase the probability of finding the global optimum (correct decryption key).

**Parameters:**
- **Restarts:** 20
- **Iterations per restart:** 3,000
- **Total evaluations:** 60,000 key variations

### 5. Key Representation

The decryption key is represented as a 26-character string where:
- Position *i* represents plaintext letter *i* (a=0, b=1, ..., z=25)
- Character at position *i* represents the corresponding cipher character
- 'x' indicates the plaintext letter was not present in the ciphertext

**Example:**
```
Plain:  a b c d e f g h i j k l m n o p q r s t u v w x y z
Key:    @ # $ 1 2 3 4 5 6 7 8 9 0 n o p q r s t u v w x y z
```
This means:
- 'a' in plaintext → '@' in ciphertext
- 'b' in plaintext → '#' in ciphertext
- etc.

---

## Implementation Details

### System Architecture

```
┌─────────────────────────────────────────────────┐
│              CipherSolver Class                  │
├─────────────────────────────────────────────────┤
│                                                  │
│  1. load_trigrams()                             │
│     - Parse trigram frequency file              │
│     - Calculate log probabilities               │
│     - Set floor value                           │
│                                                  │
│  2. score(text)                                 │
│     - Extract alphabetic characters             │
│     - Calculate trigram frequency score         │
│                                                  │
│  3. decrypt(ciphertext, key_map)                │
│     - Apply substitution key to ciphertext      │
│                                                  │
│  4. solve(ciphertext)                           │
│     - Run optimization algorithm                │
│     - Return best plaintext and key             │
│                                                  │
│  5. format_key_output(key_map, source_text)     │
│     - Format key for human readability          │
│                                                  │
└─────────────────────────────────────────────────┘
```

### Input/Output Format

**Input:** Ciphertext from standard input (stdin)

**Output:**
```
Deciphered Plaintext: [plaintext result]
Deciphered Key: [26-character key string]
```

---

## Results and Key Mappings

### General Process

For each ciphertext file, the following steps were performed:

1. **Read ciphertext** from standard input
2. **Run solver** with optimization algorithm
3. **Extract plaintext** from best solution
4. **Format decryption key** showing cipher-to-plain mapping
5. **Output results** in standardized format

### Key Format Explanation

Each key is a 26-character string representing the mapping:
- **Position:** Corresponds to plaintext letters (a-z)
- **Character:** Shows the cipher symbol that encrypts to that plaintext letter
- **'x' marker:** Indicates plaintext letter not used in the original ciphertext

**Reading the Key:**
```
Position: 0  1  2  3  4  5  ... 25
Letter:   a  b  c  d  e  f  ... z
Key:      @  #  $  1  2  3  ... y
```
Means: cipher '@' → plain 'a', cipher '#' → plain 'b', etc.

### Example Decryption

**Hypothetical Ciphertext:**
```
@211v 8vzp1
```

**Hypothetical Decrypted Plaintext:**
```
hello world
```

**Hypothetical Decryption Key:**
```
1234567890@#$zyxwvutsrqpon → abcdefghijklmnopqrstuvwxyz
```

**Interpretation:**
- Cipher '1' encrypts plain 'a'
- Cipher '2' encrypts plain 'b'
- Cipher '@' encrypts plain 'h'
- Cipher '8' encrypts plain 'w'
- etc.

---

## Actual Ciphertext Results

### Ciphertext 1

**Ciphertext:**
```
1981y, $pp1n1yuux oq@ 2@3s5u1n $p 1981y, 1v y n$s9o2x 19 v$soq yv1y. 1o 1v oq@ v@6@9oq uy27@vo n$s9o2x 5x y2@y, oq@ v@n$98 0$vo 3$3su$sv n$s9o2x, y98 oq@ 0$vo 3$3su$sv 8@0$n2ynx 19 oq@ #$2u8. 5$s98@8 5x oq@ 1981y9 $n@y9 $9 oq@ v$soq, oq@ y2y51y9 v@y $9 oq@ v$soq#@vo, y98 oq@ 5yx $p 5@97yu $9 oq@ v$soq@yvo, 1o vqy2@v uy98 5$28@2v #1oq 3yw1voy9 o$ oq@ #@vo; nq19y, 9@3yu, y98 5qsoy9 o$ oq@ 9$2oq; y98 5y97uy8@vq y98 0xy90y2 o$ oq@ @yvo. 19 oq@ 1981y9 $n@y9, 1981y 1v 19 oq@ 61n191ox $p v21 uy9wy y98 oq@ 0yu816@v; 1ov y98y0y9 y98 91n$5y2 1vuy98v vqy2@ y 0y21o10@ 5$28@2 #1oq oqy1uy98, 0xy90y2 y98 198$9@v1y. 7$$8, 9$# os29 p$2 oq@ v@n$98 3y2o $p oq@ 4s@vo1$9, 7$$8 usnw!
```

**Deciphered Plaintext:**
```
Deciphered Plaintext: india, officially the republic of india, is a country in south asia. it is the seventh largest country by area, the second most populous country, and the most populous democracy in the world. bounded by the indian ocean on the south, the arabian sea on the southwest, and the bay of bengal on the southeast, it shares land borders with pakistan to the west; china, nepal, and bhutan to the north; and bangladesh and myanmar to the east. in the indian ocean, india is in the vicinity of sri lanka and the maldives; its andaman and nicobar islands share a maritime border with thailand, myanmar and indonesia. good, now turn for the second part of the question, good luck!

```

**Deciphered Key:**
```
Deciphered Key: y5n8@p7q1xwu09$342vos6#xxx
```
---

### Ciphertext 2

**Ciphertext:**
```
64s48u46 8y6 q480ryp nrv 6ryy43 2yu$2tn46, n4 54yu u$ o46. un8u yrpnu n4 6r6 y$u vq441 54qq, n80ryp s4043rvn 6348wv, n80ryp y$ 34vu. n4 58v 2yv234 5n4un43 n4 58v 8vq441 $3 6348wryp. t$yvtr$2v, 2yt$yvtr$2v, 8qq 58v 8 oq23. n4 34w4wo4346 t3#ryp, 5rvnryp, n$1ryp, o4ppryp, 404y q82pnryp. n4 sq$8u46 un3$2pn un4 2yr043v4, v44ryp vu83v, 1q8y4uv, v44ryp 483un, 8qq o2u nrwv4qs. 5n4y n4 q$$z46 6$5y, u3#ryp u$ v44 nrv o$6#, un434 58v y$unryp. ru 58v x2vu un8u n4 58v un434, o2u n4 t$2q6 y$u s44q 8y#unryp s$3 x2vu nrv 134v4yt4.
```

**Deciphered Plaintext:**
```
Deciphered Plaintext: defeated and leaving his dinner untouched, he went to bed. that night he did not sleep well, having feverish dreams, having no rest. he was unsure whether he was asleep or dreaming. conscious, unconscious, all was a blur. he remembered crying, wishing, hoping, begging, even laughing. he floated through the universe, seeing stars, planets, seeing earth, all but himself. when he looked down, trying to see his body, there was nothing. it was just that he was there, but he could not feel anything for just his presence.
```

**Deciphered Key:**
```
Deciphered Key: 8ot64spnrxzqwy$1x3vu205x#x
```
---

### Ciphertext 3

**Ciphertext:**
```
476p61 n3zp7 26n 6 876$3nx6138 3zo36z $tuqrv13qz6$5 27q w6$1383w61to 3z 17t xv$ot$ qs 6 #vz3q$ 4$313n7 wqr38t qss38t$ 6zo 6z 3zo36z 7t6o 8qzn164rt 3z x3n169tz $t16r3613qz sq$ 17t ot617 qs 6z 3zo36z z613qz6r3n1. 7t 6rnq 1qq9 w6$1 3z 6 r6$ptr5 n5x4qr38 4qx43zp qs 17t 8tz1$6r rtp3nr613ut 6nntx4r5 3z otr73 6zo 6 7vzpt$ n1$39t 3z #63r, 27387 qz 17t 4689 qs n5xw617t138 8qut$6pt 3z 3zo36z q2zto zt2nw6wt$n 1v$zto 73x 3z1q 6 7qvnt7qro z6xt 3z wvz#64 $tp3qz, 6zo 6s1t$ 73n t0t8v13qz 86vnto 45 17t 4$313n7 $vrt$n 61 6pt 12tz15 17$tt 3z1q 6 x6$15$ 6zo sqr9 7t$q 3z zq$17t$z 3zo36.
```

**Deciphered Plaintext:**
```
Deciphered Plaintext: bhagat singh was a charismatic indian revolutionary who participated in the murder of a junior british police officer and an indian head constable in mistaken retaliation for the death of an indian nationalist. he also took part in a largely symbolic bombing of the central legislative assembly in delhi and a hunger strike in jail, which on the back of sympathetic coverage in indian owned newspapers turned him into a household name in punjab region, and after his execution caused by the british rulers at age twenty three into a martyr and folk hero in northern india.
```

**Deciphered Key:**
```
Deciphered Key: 648otsp73#9rxzqwx$n1vu205x
```

## Algorithm Performance

### Strengths

1. **Effective for longer texts:** Trigram statistics become more reliable with more data
2. **No manual intervention:** Fully automated cryptanalysis
3. **Robust to noise:** Floor values prevent single bad trigrams from dominating
4. **Multiple restarts:** Reduces likelihood of local optima

### Limitations

1. **Requires English text:** Assumes plaintext follows English trigram patterns
2. **Computational cost:** 60,000 evaluations per ciphertext
3. **Short texts:** May struggle with very short ciphertexts (< 100 characters)
4. **Proper nouns:** Unusual names may have unexpected trigram patterns

### Potential Improvements

1. **Adaptive iterations:** Increase steps for longer texts
2. **Simulated annealing:** Add probabilistic acceptance of worse solutions
3. **Quadgram/pentagram analysis:** Use longer n-grams for better accuracy
4. **Dictionary lookup:** Verify words in candidate solutions
5. **Parallel processing:** Run multiple restarts simultaneously

---

## Technical Specifications

### Files Required

- `solve.py` - Main solver implementation
- `trigram.txt` - Trigram frequency database
- Ciphertext files - Input files to decrypt

### Execution

```bash
python3 cipher_solver.py < ciphertext.txt
```

**Output:**
```
Deciphered Plaintext: [result]
Deciphered Key: [26-character key]
```

---

## Cryptanalysis Methodology

### Frequency Analysis Foundation

Classical substitution ciphers are vulnerable to frequency analysis because:

1. **Character frequency preservation:** The substitution doesn't change how often letters appear
2. **Pattern preservation:** Common English patterns (THE, ING, etc.) remain detectable
3. **Statistical fingerprint:** Each language has characteristic n-gram distributions

### Why This Attack Works

1. **Deterministic substitution:** Same plaintext letter always maps to same cipher symbol
2. **One-to-one mapping:** Bijective function between alphabets
3. **No key variation:** Single key used for entire message
4. **Statistical regularity:** English text has predictable statistical properties

### Defense Mechanisms (Not Present)

Modern encryption avoids these vulnerabilities through:
- **Polyalphabetic ciphers:** Multiple substitution alphabets
- **Block ciphers:** Encrypt groups of characters together
- **Diffusion:** Each plaintext bit affects many ciphertext bits
- **Key scheduling:** Varying keys throughout encryption

---

## Conclusion

The implemented solution successfully decrypts monoalphabetic substitution ciphers using statistical frequency analysis combined with optimization techniques. The trigram-based scoring system provides a robust measure of "English-ness," while the hill-climbing algorithm with multiple random restarts effectively searches the key space for optimal solutions.

This approach demonstrates the fundamental weakness of classical substitution ciphers: they preserve the statistical properties of the plaintext, making them vulnerable to automated cryptanalysis even without prior knowledge of the key.

---
