package mokk.nlp.ocamorph;

import java.util.Set;

public abstract class IOcamorphStemmer {
	
	/**
	 * Descendants will implement the Set<String> getStems(String word)
	 * that is the method which return a Set of words containing the stems.
	 * @param word
	 * @return
	 */
	public abstract Set<String> getStems(String word);
	
	/**
	 * Descendants will implement the Set<String> getStems(String word)
	 * that is the method which return a Set of words containing the stems.
	 * This method returns the first stem. 
	 * If the stemmer does not return anything, 
	 * then this method returns the original word.
	 * If the stemmer returns more than one word,
	 * then this method returns the first one. 
	 * @param word
	 * @return
	 *
	public String getStem(String word) {
		String result = null;
		Set<String> stems = getStems(word);
		if (stems.size() > 0) {
			result = stems.iterator().next();
		} else {
			result = word;
		}
		return result;
	}
	*/
}
