from google import genai

# The client gets the API key from the environment variable `GEMINI_API_KEY`.
client = genai.Client()

response = client.models.generate_content(
    model="gemini-3-flash-preview", contents="""You are a drum generator. Given an input drum pattern you will output a slight variation of that drum pattern ensuring that the total loop duration is exactly the same. Ensure you always understand the users groove first before trying to variate



# Track 0 Drum Data

# Format: DRUM_CLASS,TIMESTAMP,VELOCITY,DELTA_TIME

# Classes: 0=kick, 1=snare, 2=hat

# DELTA_TIME: Duration until next hit (for last hit: time until loop end)

# Total loop duration: 5.061950 seconds

0,0.084172,0.482133,0.635646

1,0.719819,0.132769,0.635646

0,1.355465,0.272635,0.632744

1,1.988209,0.123715,0.641451

0,2.629660,0.326760,0.606621

1,3.236281,0.216937,0.609524

0,3.845805,0.329060,0.641451

1,4.487256,0.253780,0.574694"""
)
print(response.text)