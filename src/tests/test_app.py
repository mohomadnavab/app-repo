"""
Unit tests for the GitOps EKS demo application.
These run in CI (before Docker build) to prevent broken code from being deployed.
FIX HIGH-07: CI had no test stage — broken code would auto-deploy to EKS.
"""
import sys
import os

# Allow imports from parent directory (src/)
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import pytest
from app import app as flask_app


@pytest.fixture
def client():
    flask_app.config["TESTING"] = True
    with flask_app.test_client() as client:
        yield client


class TestIndexEndpoint:
    def test_returns_200(self, client):
        response = client.get("/")
        assert response.status_code == 200

    def test_content_type_is_json(self, client):
        response = client.get("/")
        assert response.content_type == "application/json"

    def test_response_has_status_ok(self, client):
        data = client.get("/").get_json()
        assert data["status"] == "ok"

    def test_response_has_message(self, client):
        data = client.get("/").get_json()
        assert "message" in data
        assert len(data["message"]) > 0

    def test_response_has_version(self, client):
        data = client.get("/").get_json()
        assert "version" in data


class TestHealthEndpoint:
    def test_returns_200(self, client):
        response = client.get("/health")
        assert response.status_code == 200

    def test_response_is_healthy(self, client):
        data = client.get("/health").get_json()
        assert data["status"] == "healthy"


class TestUnknownRoute:
    def test_returns_404(self, client):
        response = client.get("/nonexistent")
        assert response.status_code == 404
