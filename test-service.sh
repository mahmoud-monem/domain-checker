#!/bin/bash

# Test script for Domain Checker Proxy Service
# This script helps you test the service locally

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROXY_URL="http://localhost"
HEALTH_ENDPOINT="/health"
CACHE_CLEAR_ENDPOINT="/admin/cache/clear"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to test health endpoint
test_health() {
    print_status "Testing health endpoint..."
    
    response=$(curl -s -o /dev/null -w "%{http_code}" "$PROXY_URL$HEALTH_ENDPOINT")
    
    if [ "$response" = "200" ]; then
        print_success "Health check passed (HTTP $response)"
        return 0
    else
        print_error "Health check failed (HTTP $response)"
        return 1
    fi
}

# Function to test domain validation
test_domain() {
    local domain=$1
    local expected_status=$2
    
    print_status "Testing domain: $domain"
    
    response=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: $domain" "$PROXY_URL/")
    
    if [ "$response" = "$expected_status" ]; then
        print_success "Domain $domain returned expected status: $response"
        return 0
    else
        print_error "Domain $domain returned unexpected status: $response (expected: $expected_status)"
        return 1
    fi
}

# Function to test cache clearing
test_cache_clear() {
    print_status "Testing cache clear endpoint..."
    
    response=$(curl -s "$PROXY_URL$CACHE_CLEAR_ENDPOINT")
    
    if [[ "$response" == *"Cache cleared successfully"* ]]; then
        print_success "Cache cleared successfully"
        return 0
    else
        print_error "Cache clear failed: $response"
        return 1
    fi
}

# Function to test rate limiting
test_rate_limiting() {
    print_status "Testing rate limiting..."
    
    # Make multiple requests quickly
    for i in {1..25}; do
        curl -s -o /dev/null -H "Host: test-rate-limit.com" "$PROXY_URL/" &
    done
    
    wait
    
    # Check if we get rate limited
    response=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: test-rate-limit.com" "$PROXY_URL/")
    
    if [ "$response" = "429" ]; then
        print_success "Rate limiting is working (HTTP $response)"
        return 0
    else
        print_warning "Rate limiting test inconclusive (HTTP $response)"
        return 1
    fi
}

# Function to check if service is running
check_service_running() {
    print_status "Checking if service is running..."
    
    if ! curl -s "$PROXY_URL$HEALTH_ENDPOINT" > /dev/null; then
        print_error "Service is not running or not accessible at $PROXY_URL"
        print_status "Please start the service with: docker-compose up -d"
        exit 1
    fi
    
    print_success "Service is running"
}

# Function to show service logs
show_logs() {
    print_status "Showing service logs..."
    docker-compose logs -f nginx
}

# Function to monitor domain checks
monitor_domain_checks() {
    print_status "Monitoring domain checks (press Ctrl+C to stop)..."
    docker-compose exec nginx tail -f /var/log/nginx/domain_check.log
}

# Main menu
show_menu() {
    echo
    echo "Domain Checker Proxy Service - Test Script"
    echo "=========================================="
    echo
    echo "1. Run all tests"
    echo "2. Test health endpoint"
    echo "3. Test domain validation"
    echo "4. Test cache clearing"
    echo "5. Test rate limiting"
    echo "6. Clear cache"
    echo "7. Show logs"
    echo "8. Monitor domain checks"
    echo "9. Exit"
    echo
}

# Function to run all tests
run_all_tests() {
    echo
    print_status "Running all tests..."
    echo
    
    local passed=0
    local failed=0
    
    # Test health endpoint
    if test_health; then
        ((passed++))
    else
        ((failed++))
    fi
    
    echo
    
    # Test valid domain (you need to have a mock backend for this)
    print_warning "Note: The following domain tests require a mock backend running on port 3010"
    print_status "You can start a mock backend with the script provided in the README"
    
    if test_domain "test.com" "200"; then
        ((passed++))
    else
        ((failed++))
    fi
    
    echo
    
    # Test invalid domain
    if test_domain "nonexistent-domain.com" "302"; then
        ((passed++))
    else
        ((failed++))
    fi
    
    echo
    
    # Test cache clearing
    if test_cache_clear; then
        ((passed++))
    else
        ((failed++))
    fi
    
    echo
    
    # Test rate limiting
    if test_rate_limiting; then
        ((passed++))
    else
        ((failed++))
    fi
    
    echo
    print_status "Test Results: $passed passed, $failed failed"
    
    if [ $failed -eq 0 ]; then
        print_success "All tests passed!"
    else
        print_error "Some tests failed. Check the output above."
    fi
}

# Function to test domain validation interactively
test_domain_interactive() {
    echo
    read -p "Enter domain to test: " domain
    read -p "Enter expected HTTP status code (e.g., 200, 302, 403): " expected_status
    
    echo
    test_domain "$domain" "$expected_status"
}

# Check if service is running first
check_service_running

# Main loop
while true; do
    show_menu
    read -p "Choose an option (1-9): " choice
    
    case $choice in
        1)
            run_all_tests
            ;;
        2)
            test_health
            ;;
        3)
            test_domain_interactive
            ;;
        4)
            test_cache_clear
            ;;
        5)
            test_rate_limiting
            ;;
        6)
            curl -s "$PROXY_URL$CACHE_CLEAR_ENDPOINT"
            echo
            ;;
        7)
            show_logs
            ;;
        8)
            monitor_domain_checks
            ;;
        9)
            print_status "Goodbye!"
            exit 0
            ;;
        *)
            print_error "Invalid option. Please choose 1-9."
            ;;
    esac
    
    echo
    read -p "Press Enter to continue..."
done 