from fastapi import APIRouter, FastAPI
from pydantic import BaseModel
from guidance import models, gen
import uvicorn
from contextlib import asynccontextmanager

class CompletionRequest(BaseModel):
    model : str
    prompt: str



avail_models = {}

@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Instantiate the model and put it in a global dictionary for later reuse

    It would be preferable to read the model path form a yaml or something
    """
    # Load the ML model
    avail_models["phi3"] = models.LlamaCpp("/Users/agreen/LLMs/phi-3-mini-128K-Instruct_q4_k_m.gguf", n_gpu_layers=-1)
    yield
    # Clean up the ML models and release the resources
    avail_models.clear()


## Create the FastAPI ap and router

app = FastAPI(lifespan=lifespan)
router = APIRouter()


@router.get('/api/tags')
def tags():
    """
    Mindsdb calls this endpoint to check ollama is running. It only checks for status code 200 so we 
    return any old junk
    """
    return "OK"


@router.post('/api/generate')
def generate(completion_request: CompletionRequest):
    """
    This is the main endpoint we imitate from ollama. it is expecting the request to have two things in it:
    model: A string, currently using phi3, but could add more
    prompt: The prompt from the user. This isn't currently multi-turn, though we could make it be I guess.
    """
    model = avail_models[completion_request.model]
    response = model + f"<|user|>{completion_request.prompt}<|end|><|assistant|>{gen('answer', stop='<|end|>')}"
    print(response['answer'])
    return {"response":response['answer'].replace("<|assistant|>", "").strip()}

## Link things up
app.include_router(router)

## Explicitly run the app in uvicorn 
if __name__ == "__main__":
    uvicorn.run(app, host='0.0.0.0', port=8000)

    


