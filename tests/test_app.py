from app import app

client = app.test_client()

def test_home():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json["application"] == "DevSecOps in a Box"

def test_health():
    response = client.get("/health")
    assert response.status_code == 200
