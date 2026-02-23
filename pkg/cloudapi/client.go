package cloudapi

import (
	"backend/internal/models"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

// Client handles communication with cloud API
type Client struct {
	baseURL    string
	apiKey     string
	outletID   string
	outletCode string
	httpClient *http.Client
}

// NewClient creates a new cloud API client
func NewClient(baseURL, apiKey, outletID, outletCode string) *Client {
	return &Client{
		baseURL:    baseURL,
		apiKey:     apiKey,
		outletID:   outletID,
		outletCode: outletCode,
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
	}
}

// PushBatch sends multiple entities to cloud in a single request
func (c *Client) PushBatch(ctx context.Context, items []models.CloudSyncItem) (*models.CloudSyncResponse, error) {
	if c.baseURL == "" || c.apiKey == "" {
		return nil, fmt.Errorf("cloud API not configured")
	}

	request := models.CloudSyncRequest{
		OutletID:      c.outletID,
		OutletCode:    c.outletCode,
		SyncTimestamp: time.Now(),
		Items:         items,
	}

	url := fmt.Sprintf("%s/api/v1/outlets/%s/sync/batch", c.baseURL, c.outletID)

	jsonData, err := json.Marshal(request)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewBuffer(jsonData))
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+c.apiKey)
	req.Header.Set("X-Outlet-ID", c.outletID)
	req.Header.Set("X-Outlet-Code", c.outletCode)

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to send request: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("cloud API error: status=%d, body=%s", resp.StatusCode, string(body))
	}

	var syncResp models.CloudSyncResponse
	if err := json.Unmarshal(body, &syncResp); err != nil {
		return nil, fmt.Errorf("failed to unmarshal response: %w", err)
	}

	return &syncResp, nil
}

// PushOrder sends a single order to cloud
func (c *Client) PushOrder(ctx context.Context, order map[string]interface{}) (string, error) {
	if c.baseURL == "" || c.apiKey == "" {
		return "", fmt.Errorf("cloud API not configured")
	}

	// Add outlet info
	order["outlet_id"] = c.outletID
	order["outlet_code"] = c.outletCode

	url := fmt.Sprintf("%s/api/v1/outlets/%s/orders", c.baseURL, c.outletID)

	jsonData, err := json.Marshal(order)
	if err != nil {
		return "", fmt.Errorf("failed to marshal order: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewBuffer(jsonData))
	if err != nil {
		return "", fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+c.apiKey)
	req.Header.Set("X-Outlet-ID", c.outletID)
	req.Header.Set("X-Outlet-Code", c.outletCode)

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("failed to send request: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("failed to read response: %w", err)
	}

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
		return "", fmt.Errorf("cloud API error: status=%d, body=%s", resp.StatusCode, string(body))
	}

	var result struct {
		Success bool `json:"success"`
		Data    struct {
			CloudID string `json:"cloud_id"`
		} `json:"data"`
	}

	if err := json.Unmarshal(body, &result); err != nil {
		return "", fmt.Errorf("failed to unmarshal response: %w", err)
	}

	return result.Data.CloudID, nil
}

// PushTransaction sends a single transaction to cloud
func (c *Client) PushTransaction(ctx context.Context, transaction map[string]interface{}) (string, error) {
	if c.baseURL == "" || c.apiKey == "" {
		return "", fmt.Errorf("cloud API not configured")
	}

	// Add outlet info
	transaction["outlet_id"] = c.outletID
	transaction["outlet_code"] = c.outletCode

	url := fmt.Sprintf("%s/api/v1/outlets/%s/transactions", c.baseURL, c.outletID)

	jsonData, err := json.Marshal(transaction)
	if err != nil {
		return "", fmt.Errorf("failed to marshal transaction: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewBuffer(jsonData))
	if err != nil {
		return "", fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+c.apiKey)
	req.Header.Set("X-Outlet-ID", c.outletID)
	req.Header.Set("X-Outlet-Code", c.outletCode)

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("failed to send request: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("failed to read response: %w", err)
	}

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
		return "", fmt.Errorf("cloud API error: status=%d, body=%s", resp.StatusCode, string(body))
	}

	var result struct {
		Success bool `json:"success"`
		Data    struct {
			CloudID string `json:"cloud_id"`
		} `json:"data"`
	}

	if err := json.Unmarshal(body, &result); err != nil {
		return "", fmt.Errorf("failed to unmarshal response: %w", err)
	}

	return result.Data.CloudID, nil
}

// PushProduct sends a single product to cloud
func (c *Client) PushProduct(ctx context.Context, product map[string]interface{}) (string, error) {
	if c.baseURL == "" || c.apiKey == "" {
		return "", fmt.Errorf("cloud API not configured")
	}

	// Add outlet info
	product["outlet_id"] = c.outletID
	product["outlet_code"] = c.outletCode

	url := fmt.Sprintf("%s/api/v1/outlets/%s/products", c.baseURL, c.outletID)

	jsonData, err := json.Marshal(product)
	if err != nil {
		return "", fmt.Errorf("failed to marshal product: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewBuffer(jsonData))
	if err != nil {
		return "", fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+c.apiKey)
	req.Header.Set("X-Outlet-ID", c.outletID)
	req.Header.Set("X-Outlet-Code", c.outletCode)

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("failed to send request: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("failed to read response: %w", err)
	}

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
		return "", fmt.Errorf("cloud API error: status=%d, body=%s", resp.StatusCode, string(body))
	}

	var result struct {
		Success bool `json:"success"`
		Data    struct {
			CloudID string `json:"cloud_id"`
		} `json:"data"`
	}

	if err := json.Unmarshal(body, &result); err != nil {
		return "", fmt.Errorf("failed to unmarshal response: %w", err)
	}

	return result.Data.CloudID, nil
}

// GetUpdates retrieves updates from cloud since specific timestamp
func (c *Client) GetUpdates(ctx context.Context, since time.Time) (map[string]interface{}, error) {
	if c.baseURL == "" || c.apiKey == "" {
		return nil, fmt.Errorf("cloud API not configured")
	}

	url := fmt.Sprintf("%s/api/v1/outlets/%s/updates?since=%s",
		c.baseURL, c.outletID, since.Format(time.RFC3339))

	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Authorization", "Bearer "+c.apiKey)
	req.Header.Set("X-Outlet-ID", c.outletID)
	req.Header.Set("X-Outlet-Code", c.outletCode)

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to send request: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("cloud API error: status=%d, body=%s", resp.StatusCode, string(body))
	}

	var result map[string]interface{}
	if err := json.Unmarshal(body, &result); err != nil {
		return nil, fmt.Errorf("failed to unmarshal response: %w", err)
	}

	return result, nil
}

// Ping checks if cloud API is reachable
func (c *Client) Ping(ctx context.Context) error {
	if c.baseURL == "" || c.apiKey == "" {
		return fmt.Errorf("cloud API not configured")
	}

	url := fmt.Sprintf("%s/api/v1/ping", c.baseURL)

	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Authorization", "Bearer "+c.apiKey)

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("failed to ping cloud: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("cloud API not available: status=%d", resp.StatusCode)
	}

	return nil
}
