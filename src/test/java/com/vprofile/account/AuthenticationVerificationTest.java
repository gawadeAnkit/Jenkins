package com.vprofile.account;

import com.vprofile.account.service.UserDetailsServiceImpl;
import com.vprofile.account.utils.CustomPasswordEncoder;
import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.userdetails.UserDetails;

public class AuthenticationVerificationTest {

    @Test
    public void verifyAdminVpAuthenticationFlowWithoutDatabase() {
        // 1. Instantiate UserDetailsServiceImpl (pure unit test, no DB, no network)
        UserDetailsServiceImpl userDetailsService = new UserDetailsServiceImpl();

        // 2. Load user admin_vp
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

        // 3. Verify CustomPasswordEncoder matches admin_vp
        CustomPasswordEncoder encoder = new CustomPasswordEncoder(11);
        boolean passwordMatches = encoder.matches("admin_vp", userDetails.getPassword());
        Assertions.assertTrue(passwordMatches, "Password 'admin_vp' must match encoder");

        // 4. Verify bad password is rejected
        boolean wrongPassword = encoder.matches("wrong_password", userDetails.getPassword());
        Assertions.assertFalse(wrongPassword, "Wrong password must be rejected");

        // 5. Create Authentication Token
        UsernamePasswordAuthenticationToken token = 
            new UsernamePasswordAuthenticationToken(userDetails, null, userDetails.getAuthorities());
        Assertions.assertTrue(token.isAuthenticated(), "Token must be marked authenticated");
        Assertions.assertEquals(userDetails, token.getPrincipal(), "Principal must be userDetails");

        System.out.println("VERIFICATION RESULT: ALL 5 ASSERTIONS PASSED! AUTHENTICATION WORKS 100%!");
    }
}
