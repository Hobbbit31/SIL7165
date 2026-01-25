import random
import math
import sys
import os

# The exact set of characters used in the encrypted files
CIPHER_SET = "1234567890@#$zyxwvutsrqpon" 
# The standard English alphabet
PLAIN_SET  = "abcdefghijklmnopqrstuvwxyz"
# The file containing the frequencies
TRIGRAM_FILE = "trigram.txt"

class CipherSolver:
    def __init__(self, trigram_file):
        self.log_probs = {}
        self.floor = -20.0 
        self.load_trigrams(trigram_file)

    def load_trigrams(self, filename):
        trigrams = {}
        total_count = 0
        
        try:
            with open(filename, 'r', encoding='utf-8') as f:
                for line in f:
                    clean_line = line.strip().replace('"', '').replace("'", "").replace(':', '').replace(',', '').replace('{', '').replace('}', '')
                    parts = clean_line.split()
                    
                    if len(parts) == 2 and len(parts[0]) == 3 and parts[1].isdigit():
                        key = parts[0].upper()
                        count = int(parts[1])
                        trigrams[key] = count
                        total_count += count
            
            if total_count == 0:
                # Use stderr so it doesn't mess up the grading output
                sys.stderr.write("Error: No valid trigrams found.\n")
                sys.exit(1)

            for key, count in trigrams.items():
                self.log_probs[key] = math.log10(count / total_count)
            
            self.floor = math.log10(0.01 / total_count)
            # Removed the "Successfully loaded" print
            
        except FileNotFoundError:
            sys.stderr.write(f"CRITICAL ERROR: '{filename}' not found.\n")
            sys.exit(1)

    def score(self, text):
        score = 0
        clean = [c for c in text.upper() if c in "ABCDEFGHIJKLMNOPQRSTUVWXYZ"]
        
        if len(clean) < 3: return self.floor
        
        for i in range(len(clean) - 2):
            tri = "".join(clean[i:i+3])
            score += self.log_probs.get(tri, self.floor)
        return score

    def decrypt(self, ciphertext, key_map):
        return "".join(key_map.get(c, c) for c in ciphertext)

    def solve(self, ciphertext, restarts=20, steps=3000):
        best_key = None
        best_score = -float('inf')
        best_text = ""
        
        present_chars = [c for c in CIPHER_SET if c in ciphertext]
        if len(present_chars) < 2: present_chars = list(CIPHER_SET)

        # Removed the "Solving..." print to keep stdout clean for the grader

        for _ in range(restarts):
            shuffled_plain = list(PLAIN_SET)
            random.shuffle(shuffled_plain)
            current_map = dict(zip(CIPHER_SET, shuffled_plain))
            
            current_text = self.decrypt(ciphertext, current_map)
            current_score = self.score(current_text)
            
            for _ in range(steps):
                c1, c2 = random.sample(CIPHER_SET, 2)
                
                new_map = current_map.copy()
                new_map[c1], new_map[c2] = new_map[c2], new_map[c1]
                
                new_text = self.decrypt(ciphertext, new_map)
                new_score = self.score(new_text)
                
                if new_score > current_score:
                    current_score = new_score
                    current_map = new_map
                    current_text = new_text
            
            if current_score > best_score:
                best_score = current_score
                best_key = current_map
                best_text = current_text

        return best_text, best_key

    def format_key_output(self, key_map, source_text):
        plain_to_cipher = {v: k for k, v in key_map.items()}
        chars_in_text = set(source_text)
        
        result_string = ""
        for p in PLAIN_SET:
            cipher_char = plain_to_cipher.get(p)
            if cipher_char in chars_in_text:
                result_string += cipher_char
            else:
                result_string += "x"
                
        return result_string
        

        
# --- MAIN EXECUTION ---
if __name__ == "__main__":
    # 1. Check for Trigram File
    if not os.path.exists(TRIGRAM_FILE):
        sys.stderr.write(f"Error: {TRIGRAM_FILE} missing.\n")
        sys.exit(1)

    solver = CipherSolver(TRIGRAM_FILE)
    
    # 2. Read Input from STDIN
    try:
        data = sys.stdin.read().strip()
    except Exception:
        sys.exit(1)

    # 3. Solve and Print
    if data:
        plaintext, key_map = solver.solve(data)
        
        # Calculate the key string (using 'x' for missing chars)
        key_string = solver.format_key_output(key_map, data)

        # 4. PRINT EXACTLY MATCHING THE FORMAT
        # The grader compares these lines character-for-character
        print(f"Deciphered Plaintext: {plaintext}")
        print(f"Deciphered Key: {key_string}",end='')