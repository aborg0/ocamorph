package mokk.nlp.ocamorph;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.io.OutputStreamWriter;
import java.io.UnsupportedEncodingException;

import java.util.HashMap;
import java.util.Map;
import java.util.HashSet;
import java.util.Set;

public class FileStemmer {

	/**
	 * path of the ocamorph binary resource 
	 */
	protected String ocamorphResource;
		
	/**
	 * this is the stemmer to get the stem of a token
	 */
	protected IOcamorphStemmer stemmer;
	/**
	 * encoding of the input file
	 */
	protected String fromEncoding = "ISO-8859-2";
	/**
	 * encoding of the output file
	 */
	protected String toEncoding = "ISO-8859-2";

	/**
	 * ocamorph param
	 */
	protected static boolean blocking = false;//true;
	/**
	 * ocamorph param
	 */
	protected static boolean stopAtFirst = false;
	
	protected static String SPACE = " ";
	protected static String WHITESPACE = "\\s";
	protected static String TAB = "\t";
	protected static String COLON = ":";
	protected static String NEWLINE = "\n";
		
	protected boolean debug = false;

	private static void usage(){
		System.err.println("This program builds a stem cache from an input file\n" +
				"usage: you must specify an ocamorph binary lexicon resource\n" +
				"input will be read from standard in, result will be written to standard out\n");
		System.err.println("example: mokk.nlp.ocamorph.FileStemmer [ocamorph-resource] > cacheoutput.file < input.file\n");
		System.exit(-1);
	}


	private void createCacheAndWrite(BufferedReader input,
			BufferedWriter out) throws IOException {
		//First round: create the cache in memory
		String line = null;
		Map<String, Set<String>> stemCache = new HashMap<String, Set<String>>();
		while ((line = input.readLine()) != null) {
			for (String word : line.split(" ")){
				//do not call stemmer if the word is already in cache
				if (!stemCache.containsKey(word)){
					stemCache.put(word, stemmer.getStems(word));
				}
			}
		}
		//Second round: write it out
		for (String word : stemCache.keySet()){
			out.write(word);
			out.write(COLON);
			for (String stem : stemCache.get(word)){
				out.write(stem);
				out.write(TAB);
			}
			out.write(NEWLINE);
		}
		
	}

	
	/**
	 * @param args
	 */
	public static void main(String[] args) {
		
		FileStemmer fileStemmer = new FileStemmer();
		
		if (args.length < 1) {
			usage();
		} else {
			fileStemmer.setOcamorphResource(args[0]);
		}

		OcamorphWrapper ocamorphWrapper = new OcamorphWrapper(fileStemmer.getOcamorphResource(),
				blocking, stopAtFirst, Compounds.No, Guess.NoGuess);
		ocamorphWrapper.setDebug(false);
		OcamorphStemmer stemmer = new OcamorphStemmer(ocamorphWrapper);
		stemmer.setDebug(false);
		
		
		
		fileStemmer.setStemmer(stemmer);
		fileStemmer.stemStream(System.in, System.out);
		
	}

	
	/**
	 * Read inputStream line by line
	 * Split each line by whitespace to tokens
	 * Get the stem of each token
	 * Reassemble each line using stems
	 * Write stemmed lines to outputStream
	 * @param inputStream
	 * @param outputStream
	 */
	public void stemStream(InputStream inputStream, OutputStream outputStream) {
		
        BufferedReader reader = null;
		try {
			reader = new BufferedReader(new InputStreamReader(
				inputStream, fromEncoding));			
		} catch (UnsupportedEncodingException e) {
			throw new RuntimeException("stemFile: unsupported from file encoding:"+fromEncoding, e);
		}
        
		BufferedWriter writer = null;
		try {
			try {
				writer = new BufferedWriter(new OutputStreamWriter(
					outputStream, toEncoding));					

				//Do the work
				createCacheAndWrite(reader, writer);
					
			} finally {
		        //... Close reader and writer.
		        reader.close();  // Close to unlock.
		        writer.close();  // Close to unlock and flush to disk.
			}
		} catch (IOException e) {
			throw new RuntimeException("stemFile: I/O Exception", e);
		}
        
    }
	
	
	public IOcamorphStemmer getStemmer() {
		return stemmer;
	}

	public void setStemmer(IOcamorphStemmer stemmer) {
		this.stemmer = stemmer;
	}

	public String getFromEncoding() {
		return fromEncoding;
	}

	public void setFromEncoding(String fromEncoding) {
		this.fromEncoding = fromEncoding;
	}

	public String getToEncoding() {
		return toEncoding;
	}

	public void setToEncoding(String toEncoding) {
		this.toEncoding = toEncoding;
	}

	public boolean isDebug() {
		return debug;
	}

	public void setDebug(boolean debug) {
		this.debug = debug;
	}

	public boolean isBlocking() {
		return blocking;
	}

	public void setBlocking(boolean blocking) {
		FileStemmer.blocking = blocking;
	}

	public boolean isStopAtFirst() {
		return stopAtFirst;
	}

	public void setStopAtFirst(boolean stopAtFirst) {
		FileStemmer.stopAtFirst = stopAtFirst;
	}

	public String getOcamorphResource() {
		return ocamorphResource;
	}

	public void setOcamorphResource(String ocamorphResource) {
		this.ocamorphResource = ocamorphResource;
	}


}
