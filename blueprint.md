# Project Blueprint

## Overview

This project is a Flutter application for managing tournaments. It includes an admin panel for managing users, tournaments, and payments.

## Style and Design

- **Theme:** Dark theme with red accents.
- **Primary Color:** `Colors.red`
- **Scaffold Background Color:** `Color(0xFF121212)`
- **Card Color:** `Color(0xFF1E1E1E)`

## Features

### Admin Panel

- **Admin Login:** Secure login for administrators.
- **Admin Dashboard:** Central hub for managing the application.
- **User Management:** View, search, and manage user accounts.
- **Tournament Management:** Create, manage, and delete tournaments.
- **Coin Management:** Add coins to user accounts.
- **Payment Requests:** View and manage payment requests.

## Current Plan

- The immediate next step is to integrate with a backend service like Supabase to handle authentication, data storage, and business logic. This will involve:
    - Setting up a Supabase project.
    - Creating the necessary database tables and relationships.
    - Implementing user authentication using Supabase Auth.
    - Replacing the mock data and hardcoded logic in the admin panel with real data from Supabase.
