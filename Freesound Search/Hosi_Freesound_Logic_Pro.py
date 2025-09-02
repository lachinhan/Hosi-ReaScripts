# Hosi_Freesound_Logic_Pro.py
# Version 1.3 - 31-Aug-2025
# This script is called by Hosi_Freesound_Logic_GUI_Pro.lua.

import sys
import os
import json
import requests
import traceback
import webbrowser
import threading
import time
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

# --- CONFIGURATION ---
REDIRECT_URI = "http://127.0.0.1:8008/"

# Global variable to hold the authorization code from the server
authorization_code = None

# --- OAUTH2 HTTP SERVER ---
class OAuthCallbackHandler(BaseHTTPRequestHandler):
    """A simple HTTP request handler to catch the OAuth2 callback."""
    def log_message(self, format, *args):
        return # Suppress console logging

    def do_GET(self):
        global authorization_code
        self.send_response(200)
        self.send_header("Content-type", "text/html")
        self.end_headers()
        
        query_components = parse_qs(urlparse(self.path).query)
        code = query_components.get("code", [None])[0]
        
        if code:
            authorization_code = code
            self.wfile.write(b"<html><head><style>body { font-family: sans-serif; background-color: #222; color: #eee; text-align: center; padding-top: 50px; }</style></head>")
            self.wfile.write(b"<body><h1>Authentication successful!</h1><p>You can close this window now and return to REAPER.</p></body></html>")
        else:
            self.wfile.write(b"<html><head><style>body { font-family: sans-serif; background-color: #222; color: #eee; text-align: center; padding-top: 50px; }</style></head>")
            self.wfile.write(b"<body><h1>Authentication failed.</h1><p>Please try again from the REAPER script.</p></body></html>")

# --- HELPER FUNCTIONS TO CONVERT PYTHON DICT TO LUA TABLE STRING ---

def escape_lua_string(s):
    """Escapes a string to be safely included in a Lua string literal."""
    if not isinstance(s, str):
        s = str(s)
    s = s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\r', '\\r')
    s = ''.join(c if c.isprintable() else f'\\{ord(c)}' for c in s)
    return s

def python_to_lua(obj):
    """Recursively converts a Python object to a Lua table string."""
    if obj is None: return "nil"
    if isinstance(obj, bool): return str(obj).lower()
    if isinstance(obj, (int, float)): return str(obj)
    if isinstance(obj, str): return f'"{escape_lua_string(obj)}"'
    if isinstance(obj, list): return "{" + ", ".join(python_to_lua(item) for item in obj) + "}"
    if isinstance(obj, dict):
        items = [f'["{escape_lua_string(k)}"] = {python_to_lua(v)}' for k, v in obj.items()]
        return "{" + ", ".join(items) + "}"
    return f'"{escape_lua_string(str(obj))}"'

# --- OAUTH2 FLOW FUNCTIONS ---

def start_authorization(client_id):
    """Starts the OAuth2 authorization process."""
    global authorization_code
    authorization_code = None # Reset code from previous attempts
    
    auth_url = f"https://freesound.org/apiv2/oauth2/authorize/?client_id={client_id}&response_type=code&redirect_uri={REDIRECT_URI}"
    
    httpd = None
    server_thread = None
    try:
        httpd = HTTPServer(('127.0.0.1', 8008), OAuthCallbackHandler)
        
        server_thread = threading.Thread(target=httpd.serve_forever)
        server_thread.daemon = True
        server_thread.start()
        
        webbrowser.open(auth_url)
        
        timeout = 120
        start_time = time.time()
        while authorization_code is None and (time.time() - start_time) < timeout:
            time.sleep(0.1)
            
    except Exception as e:
        return {"error": f"Could not start local server. Is port 8008 in use? Details: {e}"}
    finally:
        if httpd:
            httpd.shutdown()
            httpd.server_close()

    if authorization_code:
        return {"status": "success", "code": authorization_code}
    else:
        return {"error": "Authorization timed out or was cancelled."}


def get_access_token(client_id, client_secret, code):
    """Exchanges an authorization code for an access token."""
    token_url = "https://freesound.org/apiv2/oauth2/access_token/"
    payload = {
        "client_id": client_id,
        "client_secret": client_secret,
        "grant_type": "authorization_code",
        "code": code,
        "redirect_uri": REDIRECT_URI
    }
    try:
        response = requests.post(token_url, data=payload, timeout=10)
        response.raise_for_status()
        tokens = response.json()
        return {"status": "success", "tokens": tokens}
    except requests.exceptions.RequestException as e:
        return {"error": f"Failed to get access token. Status: {e.response.status_code if e.response else 'N/A'}, Response: {e.response.text if e.response else str(e)}"}

def get_user_info(access_token):
    """Gets information about the logged-in user."""
    url = "https://freesound.org/apiv2/me/"
    headers = {"Authorization": f"Bearer {access_token}"}
    try:
        response = requests.get(url, headers=headers, timeout=10)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        return {"error": f"Failed to get user info. Status: {e.response.status_code if e.response else 'N/A'}"}

# --- FREESOUND API FUNCTIONS ---

def search_freesound(api_key, query, cc0_only=False, max_duration=0.0, tags="", category="", page=1, sort_by="", extra_filters=None):
    """Performs a text search using an API Key, with optional extra filters."""
    base_url = "https://freesound.org/apiv2/search/text/"
    headers = {"Authorization": f"Token {api_key}"}
    params = {
        "query": query,
        "fields": "id,name,previews,username,duration,url,license,tags,num_downloads",
        "page_size": 25,
        "page": page
    }
    
    if sort_by: params["sort"] = sort_by
    
    filter_parts = []
    if cc0_only: filter_parts.append('license:"Creative Commons 0"')
    if max_duration > 0: filter_parts.append(f'duration:[* TO {max_duration}]')
    if tags:
        for tag in [t.strip() for t in tags.split(',') if t.strip()]:
            filter_parts.append(f'tag:"{tag}"')
    if category and category.lower() != "any": filter_parts.append(f'category:"{category}"')
    if extra_filters: filter_parts.append(extra_filters)

    if filter_parts: params["filter"] = " ".join(filter_parts)

    try:
        response = requests.get(base_url, headers=headers, params=params, timeout=10)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        if e.response and e.response.status_code == 401:
            return {"error": "Invalid API Key. Please check your key."}
        return {"error": f"API Error {e.response.status_code if e.response else 'N/A'}: {e.response.text if e.response else str(e)}"}

def get_similar_sounds(api_key, sound_id, page=1):
    """Gets a list of sounds similar to the given sound ID."""
    base_url = f"https://freesound.org/apiv2/sounds/{sound_id}/similar/"
    headers = {"Authorization": f"Token {api_key}"}
    params = {
        "fields": "id,name,previews,username,duration,url,license,tags,num_downloads",
        "page_size": 25,
        "page": page
    }
    try:
        response = requests.get(base_url, headers=headers, params=params, timeout=10)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        if e.response and e.response.status_code == 401:
            return {"error": "Invalid API Key. Please check your key."}
        return {"error": f"API Error {e.response.status_code if e.response else 'N/A'}: {e.response.text if e.response else str(e)}"}

def get_sound_details_oauth(sound_id, access_token):
    """Gets detailed information for a single sound, including download URL."""
    url = f"https://freesound.org/apiv2/sounds/{sound_id}/"
    headers = {"Authorization": f"Bearer {access_token}"}
    params = {"fields": "name,download,type"}
    try:
        response = requests.get(url, headers=headers, params=params, timeout=10)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        return {"error": f"Failed to get sound details. Status: {e.response.status_code if e.response else 'N/A'}"}

def download_file(url, output_path, access_token=None):
    """Downloads a file."""
    try:
        directory = os.path.dirname(output_path)
        if not os.path.exists(directory): os.makedirs(directory)
        
        headers = {}
        if access_token: headers["Authorization"] = f"Bearer {access_token}"

        with requests.get(url, headers=headers, stream=True, timeout=30) as r:
            r.raise_for_status()
            with open(output_path, 'wb') as f:
                for chunk in r.iter_content(chunk_size=8192):
                    f.write(chunk)
        return {"status": "success", "path": output_path}
    except Exception as e:
        return {"status": "error", "message": str(e)}

# --- MAIN EXECUTION BLOCK ---

if __name__ == "__main__":
    final_result_obj = {}
    try:
        if len(sys.argv) < 2:
            final_result_obj = {"error": "Insufficient arguments provided to Python script."}
        else:
            mode = sys.argv[1]
            
            if mode == "authorize":
                client_id, client_secret = sys.argv[2], sys.argv[3]
                auth_result = start_authorization(client_id)
                if "code" in auth_result:
                    final_result_obj = get_access_token(client_id, client_secret, auth_result["code"])
                else:
                    final_result_obj = auth_result

            elif mode == "get_user":
                final_result_obj = get_user_info(sys.argv[2])

            elif mode == "search":
                api_key, query, filter_cc0, max_duration, tags, category, page, sort_by = sys.argv[2:11]
                final_result_obj = search_freesound(api_key, query, filter_cc0.lower() == 'true', float(max_duration), tags if tags != "NONE" else "", category, int(page), sort_by)

            elif mode == "get_similar":
                api_key, sound_id, page = sys.argv[2], sys.argv[3], sys.argv[4]
                final_result_obj = get_similar_sounds(api_key, sound_id, int(page))

            elif mode == "get_favorites_details":
                api_key, ids_string = sys.argv[2], sys.argv[3]
                sound_ids = [sid.strip() for sid in ids_string.split(',') if sid.strip()]
                
                # OPTIMIZED: Fetch all sounds in one request using a filter
                if sound_ids:
                    id_filter = " OR ".join([f"id:{sid}" for sid in sound_ids])
                    # Use the main search function with an empty query and the ID filter
                    fav_results = search_freesound(api_key, query="", extra_filters=id_filter)
                    # The API might not return results in the same order as the IDs, so we re-order them
                    if "results" in fav_results:
                        sounds_by_id = {sound["id"]: sound for sound in fav_results["results"]}
                        sorted_results = [sounds_by_id[int(sid)] for sid in sound_ids if int(sid) in sounds_by_id]
                        fav_results["results"] = sorted_results
                        fav_results["count"] = len(sorted_results)

                    final_result_obj = fav_results
                else:
                    final_result_obj = {"count": 0, "results": [], "next": None, "previous": None}


            elif mode == "download_preview":
                final_result_obj = download_file(sys.argv[2], sys.argv[3])

            elif mode == "download_original":
                sound_id, download_path, access_token = sys.argv[2], sys.argv[3], sys.argv[4]
                details = get_sound_details_oauth(sound_id, access_token)
                if "error" in details:
                    final_result_obj = details
                else:
                    original_filename = f"{details['name']}.{details['type']}"
                    safe_filename = "".join(c for c in original_filename if c.isalnum() or c in '._-').rstrip()
                    full_path = os.path.join(download_path, safe_filename)
                    final_result_obj = download_file(details['download'], full_path, access_token)
            
            else:
                final_result_obj = {"error": f"Invalid mode: '{mode}'."}

    except Exception as e:
        tb_str = traceback.format_exc()
        final_result_obj = {"error": f"Unhandled Python exception: {str(e)}\n{tb_str}"}
    
    print("return " + python_to_lua(final_result_obj), end='')

