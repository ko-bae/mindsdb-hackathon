from fastapi import APIRouter, FastAPI
from pydantic import BaseModel
from guidance import models, gen
import uvicorn
from contextlib import asynccontextmanager
import yaml
import os

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
    ## Check env variables to see if a YAML has been set, if not, fallback to default
    yaml_path = os.getenv("CONFIG_YAML", "/code/agent/default_config.yaml")
    with open(yaml_path, 'r') as stream:
        config = yaml.safe_load(stream)
    # Load the ML models
    for model in config['models']:
        for model_name, model_path in model.items():
            avail_models[model_name] = models.LlamaCpp(model_path.strip(), n_gpu_layers=-1)
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

    


