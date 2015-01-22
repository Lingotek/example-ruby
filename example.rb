require "json"
require "rest_client"

begin
  # SETUP / DEFAULT RESOURCES
  host = "https://cms.lingotek.com"
  access_token = "b068b8d9-c35b-3139-9fe2-e22ee7998d9f"  # sandbox token
  community_id = "f49c4fca-ff93-4f01-a03e-aa36ddb1f2b8"  # sandbox community
  project_id = "103956f4-17cf-4d79-9d15-5f7b7a88dee2"  # sandbox project

  # prepare common headers for each request
  headers = {
    "Authorization" => "Bearer #{access_token}"
  }

  # COMMUNITY
  puts "\nCOMMUNITY"
  res = RestClient.get "#{host}/api/community", headers
  puts "\t#{res.code}"
  puts "\t#{res.body}"
  
  # PROJECT
  puts "\nPROJECT"
  res = RestClient.get("#{host}/api/project/#{project_id}", headers) {|response, request, result| response }
  if(res.code == 200)
    res_json = JSON.parse(res.body)
    puts "\tProject (existing): #{res_json['properties']['title']} (#{res_json['properties']['id']})"
  else
    project_title = "Sample Project"
    payload = {
      "title" => project_title,
      "workflow_id" => "c675bd20-0688-11e2-892e-0800200c9a66", # machine translation workflow
      "community_id" => community_id
    }
    res = RestClient.post "#{host}/api/project", payload, headers
    if(res.code == 201)
      res_json = JSON.parse(res.body)
      project_id = res_json['properties']['id']
      puts "\tProject created: #{project_title} (#{project_id})"
    else
      puts "\t #{res.code}"
      puts "\tThere was an error creating the project."
      exit
    end
  end
  
  # CREATE DOCUMENT
  puts "\nDOCUMENT"
  
  source_locale_code = "en-US"
  document_title = "Test Title #{Time.now.to_i}"
  payload = {
    "title" => document_title,
    "project_id" => project_id,
    "format" => "JSON",
    "charset" => "UTF-8",
    "locale_code" => source_locale_code,
    :multipart => true
  }
  
  # NOTE: use one of the following methods to set the content parameter ...
  
  # to use a String to specify content
  # create some sample content as JSON
  content = {
    "title" => "Test Title", 
    "body" => "The quick brown fox jumped over the lazy dog."
  }
  payload["content"] = content.to_json
  
  # to use a File to specify content
  #payload["content"] = File.new("/path/to/file", "rb")
  
  res = RestClient.post "#{host}/api/document", payload, headers
  if(res.code == 202)
    res_json = JSON.parse(res.body)
    document_id = res_json['properties']['id']
    puts "\t#{source_locale_code} (#{res.code})"
    puts "\t#{document_id}"
  else
    puts "\t #{res.code}"
    puts "\tFailed to upload the document."
    exit
  end
  
  # CHECK IMPORT PROGRESS
  puts "\nIMPORT STATUS"
  imported = false
  (1..30).each do |i|
    sleep(3)
    status_message = "\t #{i} | check status:"
    res = RestClient.get("#{host}/api/document/#{document_id}", headers) {|response, request, result| response }
    if(res.code == 404)
      status_message += " => importing"
    else
      status_message += " => imported!"
      imported = true
    end
    status_message += " (#{res.code})"
    puts status_message
    
    if(imported)
      break
    elsif(i == 30 && !imported)
      puts "\tDocument never imported."
      exit
    end  
  end
  
  # REQUEST TRANSLATION
  puts "\nREQUEST TRANSLATION"
  translation_locale_code = "zh-CN"
  payload = {
    "locale_code" => translation_locale_code
  }
  res = RestClient.post "#{host}/api/document/#{document_id}/translation", payload, headers
  puts "\t#{document_id} => #{translation_locale_code} (#{res.code})"
  
  # CHECK OVERALL PROGRESS
  puts "\tTRANSLATION STATUS"
  (1..50).each do |i|
    sleep(3)
    status_message = "\t #{i} | progress:"
    res = RestClient.get "#{host}/api/document/#{document_id}/status", headers
    res_json = JSON.parse(res.body)
    progress = res_json['properties']['progress']
    status_message += " #{progress}%"
    status_message += " (#{res.code})"
    puts status_message
    
    if(progress == 100)
      break
    elsif(i == 50)
      puts "\tDocument never imported."
      exit
    end  
  end
  
  # DOWNLOAD TRANSLATIONS
  puts "\nDOWNLOAD TRANSLATIONS"
  download_headers = {
    "Accept" => "application/json, text/plain, */*",
    :params => {
      "locale_code" => translation_locale_code
    }
  }
  res = RestClient.get "#{host}/api/document/#{document_id}/content", headers.merge(download_headers)
  puts "\t#{translation_locale_code} (#{res.code})"
  puts "\t#{res.body}"
  
  # DELETE DOCUMENT
  puts "\nCLEANUP"
  res = RestClient.delete "#{host}/api/document/#{document_id}", headers
  puts "\tDelete Document: #{document_id} (#{res.code})"
  if(res.code != 204)
    puts "\tFailed to delete document."
    puts res.body
    exit
  end
rescue Exception => e
  puts e.message  
  puts e.backtrace.inspect
end
