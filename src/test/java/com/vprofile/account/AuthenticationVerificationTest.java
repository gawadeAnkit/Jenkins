package com.vprofile.account;

import com.vprofile.account.model.Role;
import com.vprofile.account.model.User;
import com.vprofile.account.repository.UserRepository;
import com.vprofile.account.service.UserDetailsServiceImpl;
import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.HashSet;
import java.util.Set;

public class AuthenticationVerificationTest {

    @Test
    public void verifyStandardBCryptAuthenticationFlowWithDatabaseModel() {
        // 1. Create Mock UserRepository
        UserRepository userRepository = Mockito.mock(UserRepository.class);

        // 2. Prepare test user entity as stored in MySQL RDS (accountsdb.sql)
        User testUser = new User();
        testUser.setId(4L);
        testUser.setUsername("admin_vp");
        // BCrypt hash for "admin_vp"
        testUser.setPassword("$2a$11$0a7VdTr4rfCQqtsvpng6GuJnzUmQ7gZiHXgzGPgm5hkRa3avXgBLK");

        Set<Role> roles = new HashSet<>();
        Role userRole = new Role();
        userRole.setName("ROLE_USER");
        Role adminRole = new Role();
        adminRole.setName("ROLE_ADMIN");
        roles.add(userRole);
        roles.add(adminRole);
        testUser.setRoles(roles);

        Mockito.when(userRepository.findByUsername("admin_vp")).thenReturn(testUser);

        // 3. Instantiate Service and inject mock
        UserDetailsServiceImpl userDetailsService = new UserDetailsServiceImpl();
        ReflectionTestUtils.setField(userDetailsService, "userRepository", userRepository);

        // 4. Load user from service
        UserDetails userDetails = userDetailsService.loadUserByUsername("admin_vp");
        Assertions.assertNotNull(userDetails, "UserDetails must not be null");
        Assertions.assertEquals("admin_vp", userDetails.getUsername(), "Username must match");
        Assertions.assertTrue(
            userDetails.getAuthorities().stream().anyMatch(a -> a.getAuthority().equals("ROLE_USER")),
            "Must have ROLE_USER authority"
        );
        Assertions.assertTrue(
            userDetails.getAuthorities().stream().anyMatch(a -> a.getAuthority().equals("ROLE_ADMIN")),
            "Must have ROLE_ADMIN authority"
        );

        // 5. Verify standard BCryptPasswordEncoder matches raw password against hash
        BCryptPasswordEncoder encoder = new BCryptPasswordEncoder(11);
        boolean passwordMatches = encoder.matches("admin_vp", userDetails.getPassword());
        Assertions.assertTrue(passwordMatches, "Password 'admin_vp' must match BCrypt hash");

        // 6. Verify bad password is rejected
        boolean wrongPassword = encoder.matches("invalid_password", userDetails.getPassword());
        Assertions.assertFalse(wrongPassword, "Invalid password must be rejected");

        // 7. Verify security token creation
        UsernamePasswordAuthenticationToken token =
            new UsernamePasswordAuthenticationToken(userDetails, null, userDetails.getAuthorities());
        Assertions.assertTrue(token.isAuthenticated(), "Token must be authenticated");

        // 8. Verify non-existent user throws UsernameNotFoundException
        Assertions.assertThrows(UsernameNotFoundException.class, () -> {
            userDetailsService.loadUserByUsername("non_existent_user");
        });

        System.out.println("TEST SUCCESS: 100% standard BCrypt + Database UserDetailsService flow verified!");
    }
}
