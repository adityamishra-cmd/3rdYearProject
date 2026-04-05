import asyncio
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException
from pydantic import BaseModel
import uvicorn

app = FastAPI()

paired_unique_id: str | None = None
nodemcu_socket: WebSocket | None = None 

class PairRequest(BaseModel):
    uniqueId: str

class CommandRequest(BaseModel):
    command: str
    uniqueId: str

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    global nodemcu_socket
    await websocket.accept()
    nodemcu_socket = websocket
    print("NodeMCU connect ho gaya hai.")
    try:
        while True:
            message = await websocket.receive_text()
            print(f"NodeMCU se message aaya: {message}")
    except WebSocketDisconnect:
        nodemcu_socket = None 
        print("NodeMCU disconnect ho gaya.")
    except Exception as e:
        print(f"Ek error aayi: {e}")
        nodemcu_socket = None


@app.post("/pair")
async def pair_device(request: PairRequest):
    global paired_unique_id
    if not request.uniqueId:
        raise HTTPException(status_code=400, detail="Error: uniqueId nahi mila.")
    
    paired_unique_id = request.uniqueId
    print(f"Naya device pair hua. Unique ID: {paired_unique_id}")
    return {"message": "Pairing safal hui!", "pairedId": paired_unique_id}

@app.post("/command")
async def send_command(request: CommandRequest):
    global nodemcu_socket
    global paired_unique_id

    if not request.command or not request.uniqueId:
        raise HTTPException(status_code=400, detail="Error: Command ya uniqueId nahi mila.")

    if not paired_unique_id:
        print("Reject kiya: Koi device paired nahi hai.")
        raise HTTPException(status_code=403, detail="Kripya pehle device pair karein.")

    if request.uniqueId != paired_unique_id:
        print(f"Reject kiya: Galat Unique ID. Aaya: {request.uniqueId}, Chahiye: {paired_unique_id}")
        raise HTTPException(status_code=401, detail="Unique ID match nahi hua. Access denied.")

    if nodemcu_socket:
        try:
            await nodemcu_socket.send_text(request.command)
            print(f"Command '{request.command}' NodeMCU ko bheja gaya.")
            return {"message": f"Command '{request.command}' safaltapoorvak bheja gaya."}
        except Exception as e:
            print(f"NodeMCU ko command bhejte waqt error aayi: {e}")
            raise HTTPException(status_code=500, detail="NodeMCU ko command nahi bhej paaye.")
    else:
        print("Rejected: NodeMCU is not connected.")
        raise HTTPException(status_code=500, detail="NodeMCU server se connected nahi hai.")

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=3000)