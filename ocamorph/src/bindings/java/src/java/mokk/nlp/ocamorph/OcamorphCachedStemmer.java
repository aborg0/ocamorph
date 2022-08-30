package mokk.nlp.ocamorph;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.io.OutputStreamWriter;
import java.io.UnsupportedEncodingException;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

/**
 * This class adds caching feature to an IOcamorphStemmer. 
 * 
 * 
 * @author bpgergo
 * 
 */
public class OcamorphCachedStemmer extends IOcamorphStemmer {
	protected boolean debug = false;
	protected String resourcePathStr;
	protected String resourceEncoding;
	protected File resourceFile;
	protected Map<String, Set<String>> cache;
	protected IOcamorphStemmer ocamorphStemmer;
		
	public OcamorphCachedStemmer(String resourcePath, String resourceEncoding, IOcamorphStemmer ocamorphStemmer){
		this.ocamorphStemmer = ocamorphStemmer;
		this.resourcePathStr = resourcePath;
		this.resourceEncoding = resourceEncoding;
		readResourceIntoCache();
	}
	
	/**
	 * Get the stems from the cache.
	 * If cache does not exists then fall back and call the stemmer.
	 * If the word is not found in the cache, then call the stemmer and
	 * put the stems into the cache before returning them.
	 * 
	 */
	public Set<String> getStems(String word) {
		Set<String> result = null;
		if (word != null && word.length() > 0){
			if (cache != null){
				result = cache.get(word);
				if (result != null){
					debug("found in cache:"+word);
					//there is a special rule: if the word is the stem itself, then it is not in the stem set (to save space) 
					//NO SPECIAL RULE!
					//if (result.isEmpty()){
					//	result.add(word);
					//}
				} else {
					debug("call stemmer:"+word);
					result = ocamorphStemmer.getStems(word);
					cache.put(word, result);
					debug("put in cache:"+word);
				}			
			} else {
				debug("no cache fall back:"+word);
				result = ocamorphStemmer.getStems(word);
			}
		}
		return result;
	}
	
	/**
	 * Read stem cache from file.
	 * This method is called from the constructor;
	 * Cache file format: 
	 * word1	stem1.1	stem1.2	stem1.3
	 * word2	stem2.1	stem2.2
	 * word3	stem3
	 */
	protected void readResourceIntoCache(){
		cache = new HashMap<String, Set<String>>();
		if (resourcePathStr != null){
			resourceFile = new File(resourcePathStr);
			BufferedReader fileInput = null;
			try {
				fileInput = new BufferedReader(new InputStreamReader(
						new FileInputStream(resourceFile), resourceEncoding));
				String line = null;
				try{
					while (( line = fileInput.readLine()) != null){
						if (line.length() > 0){
							boolean first = true;
							Set<String> set = null;
							for (String token : line.split("\t")){
								if (first){
									first = false;
									set = cache.get(token);
									if (set == null){
										set = new HashSet<String>();
										cache.put(token, set);
									}
								} else {
									set.add(token);
								}
							}
						}
					}
				} finally {
					fileInput.close();
				}
			} catch (UnsupportedEncodingException e) {
				throw new RuntimeException("unsupported encoding for ocamorph cache resource:"+resourceEncoding);
			} catch (FileNotFoundException e) {
				debug("readResourceIntoCache:FileNotFoundException");
				resourceFile = null;
			} catch (IOException ex){
				debug("readResourceIntoCache:IOException");
				resourceFile = null;
			}
		}
	}
	
	private OutputStream getResourceFileOutputStream(){
		OutputStream result = null;
		try {
			resourceFile = new File(resourcePathStr);
			result = new FileOutputStream(resourceFile);
		} catch (FileNotFoundException e) {
			debug("getResourceFileOutputStream: FileNotFoundException");
			resourceFile = null;
		}
		return result;
	}
	
	/**
	 * Write stem cache to file.
	 * This method should be called by the user,
	 * it is not called in the destructor (finalize or whatever).
	 * Cache file format: 
	 * word1	stem1.1	stem1.2	stem1.3
	 * word2	stem2.1	stem2.2
	 * word3
	 */
	public void writeResourceFromCache(){
		writeCache(null);
	}
	
	/**
	 * Write out cache into a stream.
	 * @param outputStream
	 */
	public void writeCache(OutputStream outputStream){
		if (cache != null && resourcePathStr != null){
			if (outputStream == null){
				outputStream = getResourceFileOutputStream();
			}
			
			try {
				BufferedWriter writer = new BufferedWriter(new OutputStreamWriter(
						outputStream, resourceEncoding));
				debug("writeResourceFromCache:file opened");
				try {
					for (String key : cache.keySet()){
							writer.write(key);
							Set<String> set = cache.get(key);
							if (set != null){
								for (String value : set){
									writer.write("\t");
									writer.write(value);
								}
							}
							writer.newLine();
					}
				} finally {
					writer.close();
				}				
			} catch (UnsupportedEncodingException e) {
				throw new RuntimeException("unsupported encoding for ocamorph cache resource:"+resourceEncoding);
			} catch (IOException e) {
				resourceFile = null;
				throw new RuntimeException("write cache:IOException", e);				
			}
		}
	}
	
	private void debug(String val){
		if (debug){
			System.out.println(val);
		}
	}

	public boolean isDebug() {
		return debug;
	}

	public void setDebug(boolean debug) {
		this.debug = debug;
	}
}


