import pytest
from unittest.mock import patch, MagicMock

# Patch redis.Redis before importing app to prevent real connection attempts
with patch("redis.Redis", return_value=MagicMock()):
    from main import app

from fastapi.testclient import TestClient

client = TestClient(app)


def test_health_returns_ok():
    with patch("main.r") as mock_r:
        mock_r.ping.return_value = True
        response = client.get("/health")
        assert response.status_code == 200
        assert response.json() == {"status": "ok"}


def test_create_job_returns_job_id():
    with patch("main.r") as mock_r:
        mock_r.lpush.return_value = 1
        mock_r.hset.return_value = 1
        response = client.post("/jobs")
        assert response.status_code == 200
        data = response.json()
        assert "job_id" in data
        assert len(data["job_id"]) == 36  # UUID format


def test_create_job_pushes_to_redis_queue():
    with patch("main.r") as mock_r:
        mock_r.lpush.return_value = 1
        mock_r.hset.return_value = 1
        response = client.post("/jobs")
        job_id = response.json()["job_id"]
        mock_r.lpush.assert_called_once_with("jobs", job_id)


def test_create_job_sets_queued_status():
    with patch("main.r") as mock_r:
        mock_r.lpush.return_value = 1
        mock_r.hset.return_value = 1
        response = client.post("/jobs")
        job_id = response.json()["job_id"]
        mock_r.hset.assert_called_once_with(f"job:{job_id}", "status", "queued")


def test_get_existing_job_returns_status():
    with patch("main.r") as mock_r:
        mock_r.hget.return_value = "completed"
        response = client.get("/jobs/test-job-id")
        assert response.status_code == 200
        data = response.json()
        assert data["job_id"] == "test-job-id"
        assert data["status"] == "completed"


def test_get_nonexistent_job_returns_error():
    with patch("main.r") as mock_r:
        mock_r.hget.return_value = None
        response = client.get("/jobs/nonexistent")
        assert response.status_code == 200
        assert "error" in response.json()
