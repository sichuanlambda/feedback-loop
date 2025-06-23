# Admin Portal Documentation

## Overview
The admin portal provides comprehensive management tools for the building library and user management. It allows administrators to curate, edit, and manage building analyses that appear in the public building library.

## Access
- Only users with admin privileges can access the admin portal
- Admin users will see an "Admin Panel" link in the navigation bar
- Direct URL: `/admin/dashboard`

## Features

### Dashboard (`/admin/dashboard`)
- **Statistics Overview**: Total buildings, visible buildings, users, and generated images
- **Quick Actions**: Direct links to manage building library, review hidden buildings, view public library
- **Recent Activity**: Latest buildings and user registrations
- **Popular Styles**: Chart showing most common architecture styles
- **System Information**: Environment, database, and version details

### Building Library Management (`/admin/building_analyses`)
- **Grid View**: Visual cards showing all buildings with images and metadata
- **Search & Filter**: Search by style or address, filter by visibility status
- **Bulk Actions**: Select multiple buildings and perform bulk operations
- **Individual Actions**: View, edit, toggle visibility, or delete individual buildings

### Building Details (`/admin/building_analyses/:id`)
- **Full Information**: Complete building data, user info, timestamps
- **Quick Actions**: Edit, view public page, toggle visibility, delete
- **Navigation**: Previous/next building navigation
- **Keyboard Shortcuts**: Ctrl+E to edit, Ctrl+Arrow keys to navigate

### Edit Building (`/admin/building_analyses/:id/edit`)
- **Form Interface**: Edit all building properties
- **Image Preview**: See the building image while editing
- **Style Management**: Edit architecture styles as JSON array
- **HTML Content**: Edit the full analysis content
- **Validation**: JSON validation for styles field

## Admin Commands

### Make a User Admin
```bash
rails admin:make_admin[user@example.com]
```

### Remove Admin Status
```bash
rails admin:remove_admin[user@example.com]
```

### List All Admins
```bash
rails admin:list_admins
```

## Key Features

### Visibility Management
- Buildings can be marked as visible or hidden in the public library
- Toggle visibility with a single click
- Bulk visibility changes for multiple buildings

### Content Curation
- Edit building metadata (address, city, image URL)
- Modify architecture styles
- Update HTML analysis content
- Preview changes before saving

### Search and Filter
- Search buildings by style or address
- Filter by visibility status
- Sort by creation date
- Pagination for large datasets

### Bulk Operations
- Select multiple buildings with checkboxes
- Bulk make visible/hidden
- Bulk delete (with confirmation)
- Select all functionality

### User Management
- View user information for each building
- See user registration dates
- Track user activity

## Security
- Admin authorization required for all admin routes
- Non-admin users are redirected to home page
- Confirmation dialogs for destructive actions
- CSRF protection on all forms

## Best Practices

### Content Curation
1. Regularly review new building submissions
2. Ensure architecture styles are accurate and consistent
3. Verify image quality and relevance
4. Maintain a balanced representation of different styles

### User Management
1. Only grant admin access to trusted users
2. Regularly review admin user list
3. Remove admin access when no longer needed

### Data Management
1. Back up data before bulk operations
2. Test changes on a few buildings before bulk updates
3. Monitor system statistics for unusual activity

## Troubleshooting

### Common Issues
- **Permission Denied**: Ensure user has admin privileges
- **JSON Errors**: Validate JSON format in styles field
- **Missing Images**: Check image URLs are accessible
- **Pagination Issues**: Clear browser cache if pagination doesn't work

### Performance
- Large datasets are paginated (20 items per page)
- Images are loaded asynchronously
- Search queries are optimized with database indexes

## Future Enhancements
- Export functionality for building data
- Advanced analytics and reporting
- User activity tracking
- Automated content moderation
- API endpoints for external tools 