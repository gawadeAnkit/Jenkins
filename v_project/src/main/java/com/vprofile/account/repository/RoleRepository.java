package com.vprofile.account.repository;

import org.springframework.data.jpa.repository.JpaRepository;

import com.vprofile.account.model.Role;

public interface RoleRepository extends JpaRepository<Role, Long>{
}
